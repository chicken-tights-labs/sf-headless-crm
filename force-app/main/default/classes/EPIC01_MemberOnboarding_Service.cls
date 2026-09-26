/**
 * EPIC-01: Member Onboarding — Service Class
 *
 * Implements the core business logic for:
 *   - US-002: Lead → Member conversion with waiver transfer
 *   - US-003: Payment gate validation (waiver check)
 *   - US-004: Payment processing with date/status/Classes_Remaining logic
 *   - US-005: Welcome email trigger + referral reward
 *   - US-006: Referral code generation + validation + friend discount
 *
 * Cross-reference: CRM-Documentation/EPIC-01_*.md in Obsidian vault
 */
public with sharing class EPIC01_MemberOnboarding_Service {

    // =====================================================
    // Inner Classes
    // =====================================================

    public class PaymentGateResult {
        @TestVisible public Boolean canProceed;
        @TestVisible public String   errorMessage;
        @TestVisible public String   waiverStatus; // Signed, Expired, Pending, Missing, Revoked

        public PaymentGateResult(Boolean can, String error, String status) {
            this.canProceed   = can;
            this.errorMessage = error;
            this.waiverStatus = status;
        }
    }

    // =====================================================
    // US-002: Lead → Member Conversion with Waiver Transfer
    // =====================================================

    /**
     * Converts a Lead__c to a Member__c (Prospect status).
     * Copies contact fields, sets bidirectional lookups, and transfers
     * any existing valid Waiver_Record__c from the Lead to the new Member.
     *
     * If no valid waiver is found, sets Waiver_Needed__c = true and
     * creates a follow-up task.
     */
    public static Member__c convertLeadToMember(Id leadId) {
        // 1. Query Lead__c
        Lead__c lead = [
            SELECT Id, Name, First_Name__c, Last_Name__c, Email__c, Phone__c,
                   Franchise_Location__c, Referred_By__c, Program_Interest__c,
                   Lead_Source__c, Lead_Status__c
            FROM Lead__c WHERE Id = :leadId
        ];

        // 2. Create Member__c with copied fields, Status = 'Prospect'
        Member__c newMember = new Member__c(
            Name             = lead.First_Name__c + '_' + lead.Last_Name__c,
            First_Name__c    = lead.First_Name__c,
            Last_Name__c     = lead.Last_Name__c,
            Email__c         = lead.Email__c,
            Phone__c         = lead.Phone__c,
            Home_Location__c = lead.Franchise_Location__c,
            Referred_By__c   = lead.Referred_By__c,
            Status__c        = 'Prospect',
            Waiver_Needed__c = false
        );
        insert newMember;

        // 3. Set Lead.Converted_Member__c and Lead_Status__c = 'Converted'
        lead.Lead_Status__c = 'Converted';
        lead.Converted_Member__c = newMember.Id;
        update lead;

        // 4. Query Waiver_Record__c for this Lead
        List<Waiver_Record__c> waivers = [
            SELECT Id, Member__c
            FROM Waiver_Record__c
            WHERE Lead__c = :leadId
              AND Status__c = 'Signed'
              AND (Expiration_Date__c = null OR Expiration_Date__c >= TODAY)
            LIMIT 1
        ];

        if (!waivers.isEmpty()) {
            // → Waiver found: transfer to Member
            waivers[0].Member__c = newMember.Id;
            update waivers[0];
        } else {
            // → No valid waiver: flag and create task
            newMember.Waiver_Needed__c = true;
            update newMember;

            Task t = new Task(
                WhatId   = newMember.Id,
                Subject  = 'Member needs to sign waiver',
                Status   = 'Not Started',
                Priority = 'High'
            );
            insert t;
        }

        // 5. Return newMember (re-query to ensure fresh data in memory)
        return [
            SELECT Id, Name, First_Name__c, Last_Name__c, Email__c, Phone__c,
                   Home_Location__c, Referred_By__c, Status__c, Waiver_Needed__c
            FROM Member__c WHERE Id = :newMember.Id
        ];
    }

    // =====================================================
    // US-003: Payment Gate — Waiver Validation
    // =====================================================

    /**
     * Checks whether a Member can proceed to the payment screen.
     * Gate: must have a valid signed Waiver_Record__c.
     *
     * If the member signed a waiver during a free trial class,
     * it was already transferred to Member__c during conversion (US-002).
     */
    public static PaymentGateResult attemptProceedToPayment(Id memberId) {
        // 1-2. Query Member__c and their Waiver_Record__c
        List<Waiver_Record__c> waivers = [
            SELECT Id, Status__c, Expiration_Date__c
            FROM Waiver_Record__c
            WHERE Member__c = :memberId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        // 3. Validate based on waiver status
        if (waivers.isEmpty()) {
            // 5. No waiver → blocked
            return new PaymentGateResult(
                false,
                'Please sign your waiver first',
                'Missing'
            );
        }

        Waiver_Record__c waiver = waivers[0];

        if (waiver.Status__c == 'Pending') {
            // 7. Pending waiver → blocked
            return new PaymentGateResult(
                false,
                'Waiver pending signature',
                'Pending'
            );
        }

        if (waiver.Status__c == 'Revoked') {
            // 8. Revoked waiver → blocked
            return new PaymentGateResult(
                false,
                'Waiver has been revoked',
                'Revoked'
            );
        }

        if (waiver.Status__c == 'Signed') {
            // 4. Signed waiver → check expiration
            if (waiver.Expiration_Date__c != null && waiver.Expiration_Date__c < Date.today()) {
                // 6. Expired → blocked
                return new PaymentGateResult(
                    false,
                    'Your waiver has expired',
                    'Expired'
                );
            }
            return new PaymentGateResult(true, null, 'Signed');
        }

        // Unknown status → blocked
        return new PaymentGateResult(false, 'Unable to determine waiver status', 'Unknown');
    }

    /**
     * Called by a Flow/Aura component to validate the gate before
     * navigating to the payment screen.
     * Returns a JSON string for LWC consumption.
     */
    @AuraEnabled
    public static String checkPaymentGate(Id memberId) {
        PaymentGateResult result = attemptProceedToPayment(memberId);
        return (String)JSON.serialize(result);
    }

    // =====================================================
    // US-004: Payment Processing
    // =====================================================

    // Test mock: when true, processPayment simulates a card-decline failure
    @TestVisible private static Boolean simulatePaymentFailure = false;

    /**
     * Processes a payment for a Member's selected tier.
     * Sets membership dates, updates Classes_Remaining__c,
     * transitions Status from 'Prospect' → 'Active',
     * creates Payment_Transaction__c, triggers welcome email.
     *
     * Returns true if payment succeeded, false if failed.
     */
    public static Boolean processPayment(Id memberId, String amount, String paymentMethod) {
        // 1. Query Member__c
        Member__c member = [
            SELECT Id, Name, First_Name__c, Last_Name__c, Email__c,
                   Home_Location__c, Membership_Tier__c, Referred_By__c,
                   Classes_Remaining__c, Account_Credit__c, Welcome_Email_Sent__c
            FROM Member__c WHERE Id = :memberId
        ];

        // 2. Call payment processor (Stripe) — simulated for test context
        //    In production, this would be an HTTP callout to Stripe's API
        //    For testing: simulate failure when test method name contains 'PaymentFails'
        Boolean simulateFailure = simulatePaymentFailure;

        if (simulateFailure) {
            // 4. On failure:
            //    a. Create Payment_Transaction__c with Status='Failed'
            Payment_Transaction__c failedTxn = new Payment_Transaction__c(
                Member__c             = memberId,
                Amount__c             = Decimal.valueOf(amount),
                Payment_Type__c       = mapTierToPaymentType(member.Membership_Tier__c),
                Transaction_Method__c = paymentMethod,
                Status__c             = 'Failed',
                Franchise_Location__c = member.Home_Location__c
            );
            insert failedTxn;

            //    b. Create task "Retry payment for [Member Name]"
            Task retryTask = new Task(
                WhatId   = memberId,
                Subject  = 'Retry payment for ' + member.Name,
                Status   = 'Not Started',
                Priority = 'High'
            );
            insert retryTask;

            return false;
        }

        // 3. On success:
        //    a. Set Status__c = 'Active'
        member.Status__c = 'Active';

        //    b. Set Start_Date__c = TODAY
        member.Start_Date__c = Date.today();

        //    c. Set Expiry_Date__c based on tier
        if (member.Membership_Tier__c == 'Monthly Unlimited ($129)') {
            member.Expiry_Date__c = Date.today().addDays(30);
        } else if (member.Membership_Tier__c == 'Annual Prepaid ($99/mo)') {
            member.Expiry_Date__c = Date.today().addDays(365);
        } else if (member.Membership_Tier__c == 'Drop-In ($20/class)') {
            member.Start_Date__c = null;    // No start date for pay-per-class
            member.Expiry_Date__c = null;  // No expiry for drop-in
        } else if (member.Membership_Tier__c == 'Punch Card (10 classes - $150)') {
            member.Expiry_Date__c = Date.today().addDays(180);
        }

        //    d. Set Classes_Remaining__c based on tier
        if (member.Membership_Tier__c == 'Punch Card (10 classes - $150)') {
            member.Classes_Remaining__c = 10;
        }

        //    e. Set Is_Recurring__c = true for recurring tiers
        //    f. If Referred_By__c is set → trigger referral reward (US-006)
        //    g. Trigger welcome email + orientation task (US-005)
        //    h. Create Payment_Transaction__c (Amount, Method, Status='Completed')

        update member;

        //    h. Create Payment_Transaction__c
        Payment_Transaction__c txn = new Payment_Transaction__c(
            Member__c             = memberId,
            Amount__c             = Decimal.valueOf(amount),
            Payment_Type__c       = mapTierToPaymentType(member.Membership_Tier__c),
            Transaction_Method__c = paymentMethod,
            Status__c             = 'Completed',
            Franchise_Location__c = member.Home_Location__c,
            Is_Recurring__c       = (member.Membership_Tier__c == 'Monthly Unlimited ($129)')
        );
        insert txn;

        //    f. If Referred_By__c is set → trigger referral reward (US-006)
        if (member.Referred_By__c != null) {
            awardReferralReward(member.Referred_By__c, memberId);
        }

        //    g. Trigger welcome email + orientation task (US-005)
        sendWelcomeEmail(memberId);

        return true;
    }

    /**
     * Maps a Membership_Tier__c value to the corresponding Payment_Type__c picklist value.
     */
    private static String mapTierToPaymentType(String tier) {
        if (tier == 'Monthly Unlimited ($129)') {
            return 'Monthly Fee';
        } else if (tier == 'Annual Prepaid ($99/mo)') {
            return 'Annual Prepayment';
        } else if (tier == 'Drop-In ($20/class)') {
            return 'Drop-In Fee';
        } else if (tier == 'Punch Card (10 classes - $150)') {
            return 'Punch Card Top-Up';
        }
        return 'Other';
    }

    /**
     * Calculates the final payment amount after applying any
     * referral friend discount (50% off first pack).
     */
    public static Decimal calculatePaymentWithReferralDiscount(Id memberId, String originalAmount) {
        // 1. Query Member__c (with Referred_By__c)
        Member__c member = [
            SELECT Id, Referred_By__c FROM Member__c WHERE Id = :memberId
        ];

        // 2. If Referred_By__c is set → return 50% discount AND award referral reward
        if (member.Referred_By__c != null) {
            awardReferralReward(member.Referred_By__c, memberId);
            return Decimal.valueOf(originalAmount) * 0.50;
        }

        // 3. Otherwise → return full amount
        return Decimal.valueOf(originalAmount);
    }

    // =====================================================
    // US-006: Referral Program
    // =====================================================

    /**
     * Generates a unique 8-character referral code for a Member.
     * Format: 3-char initials + 5-char random alphanumeric
     * e.g., MRXFF8A2
     */
    public static void generateReferralCode(Id memberId) {
        // 1. Query Member__c
        Member__c member = [
            SELECT Id, First_Name__c, Last_Name__c FROM Member__c WHERE Id = :memberId
        ];

        // 2. Build 3-character initials prefix
        String initials = '';
        if (String.isNotBlank(member.First_Name__c) && member.First_Name__c.length() > 0) {
            initials += member.First_Name__c.substring(0, 1).toUpperCase();
        }
        if (String.isNotBlank(member.Last_Name__c) && member.Last_Name__c.length() > 0) {
            initials += member.Last_Name__c.substring(0, 1).toUpperCase();
        }
        while (initials.length() < 3) {
            initials += 'X';
        }
        initials = initials.left(3);

        // 3. Generate code and check uniqueness — if collision, regenerate
        String code;
        Integer attempts = 0;
        Boolean isUnique = false;
        Integer counter = 0;
        do {
            // 5-char random hex from a time-seeded blob hash
            String seed = String.valueOf(Datetime.now().getTime()) + String.valueOf(counter);
            code = initials + EncodingUtil.convertToHex(Blob.valueOf(seed)).left(5);
            // Check uniqueness (exclude the current member)
            isUnique = [
                SELECT COUNT() FROM Member__c
                WHERE Referral_Code__c = :code AND Id != :memberId
            ] == 0;
            attempts++;
            counter++;
        } while (!isUnique && attempts < 5);

        // 4. Set Referral_Code__c and Referral_Attempts__c = 0
        member.Referral_Code__c = code;
        member.Referral_Attempts__c = 0;
        update member;
    }

    /**
     * Looks up a Member by their referral code.
     * Returns null if not found.
     */
    public static Member__c lookupReferralCode(String referralCode) {
        if (String.isBlank(referralCode)) return null;
        List<Member__c> members = [
            SELECT Id, Name, First_Name__c, Last_Name__c, Status__c
            FROM Member__c
            WHERE Referral_Code__c = :referralCode
            LIMIT 1
        ];
        return members.isEmpty() ? null : members[0];
    }

    /**
     * Checks if a member is attempting to refer themselves.
     */
    public static Boolean isSelfReferral(Id memberId, String referralCode) {
        Member__c referrer = lookupReferralCode(referralCode);
        if (referrer == null) return false;
        return referrer.Id == memberId;
    }

    /**
     * Checks if a referred person already exists as a member with
     * the given referrer (prevents duplicate referrals / gaming).
     */
    public static Boolean isDuplicateReferral(Id referrerId, String email) {
        // Check Member__c WHERE Email__c = :email AND Referred_By__c = :referrerId
        List<Member__c> members = [
            SELECT Id FROM Member__c
            WHERE Email__c = :email AND Referred_By__c = :referrerId
            LIMIT 1
        ];
        if (!members.isEmpty()) return true;

        // Also check Lead__c WHERE Email__c = :email AND Referred_By__c = :referrerId
        List<Lead__c> leads = [
            SELECT Id FROM Lead__c
            WHERE Email__c = :email AND Referred_By__c = :referrerId
            LIMIT 1
        ];
        return !leads.isEmpty();
    }

    /**
     * Awards the referral reward to the referring member.
     * Called when the referred member's first payment completes.
     */
    public static void awardReferralReward(Id referringMemberId, Id referredMemberId) {
        // 1. Query referring Member__c (with Membership_Tier__c, Classes_Remaining__c, Account_Credit__c)
        Member__c referrer = [
            SELECT Id, Name, Membership_Tier__c, Classes_Remaining__c, Account_Credit__c
            FROM Member__c WHERE Id = :referringMemberId
        ];

        // 2. Determine reward type:
        //    - Class pack tier → Classes_Remaining__c += 1
        //    - Unlimited/Student/Military tier → Account_Credit__c += 10
        //    - Drop-in → Account_Credit__c += 10
        Integer currentClasses = (referrer.Classes_Remaining__c == null) ? 0 : (Integer)referrer.Classes_Remaining__c;
        Decimal currentCredit = (referrer.Account_Credit__c == null) ? 0 : referrer.Account_Credit__c;

        // Award +1 class credit to all referrers
        referrer.Classes_Remaining__c = currentClasses + 1;

        // Also award account credit for unlimited/membership tiers
        if (referrer.Membership_Tier__c == 'Monthly Unlimited ($129)'
            || referrer.Membership_Tier__c == 'Annual Prepaid ($99/mo)') {
            referrer.Account_Credit__c = currentCredit + 10;
        }

        update referrer;

        // 3. Create Referral_Reward__c record (Status = 'Reward Claimed')
        Referral_Reward__c reward = new Referral_Reward__c(
            Referring_Member__c = referringMemberId,
            Referred_Member__c  = referredMemberId,
            Status__c           = 'Reward Claimed'
        );
        insert reward;

        // 4. Send notification email to referrer
        //    (Simulated — in production, send email template)
    }

    // =====================================================
    // US-005: Welcome Workflow Helpers
    // =====================================================

    /**
     * Fires the welcome email + creates orientation task.
     * Called when Member Status transitions to 'Active'.
     */
    public static void sendWelcomeEmail(Id memberId) {
        // 1. Check Welcome_Email_Sent__c == false
        Member__c member = [
            SELECT Id, Name, First_Name__c, Last_Name__c, Welcome_Email_Sent__c
            FROM Member__c WHERE Id = :memberId
        ];

        if (!member.Welcome_Email_Sent__c) {
            // 2. Send email template 'NBS_Gym_Welcome' to member
            //    (Simulated — in production, use Messaging.SingleEmailMessage)

            // 3. Create Task: "Schedule facility orientation for [Member Name]"
            Task t = new Task(
                WhatId   = memberId,
                Subject  = 'Schedule facility orientation for '
                           + member.First_Name__c + ' ' + member.Last_Name__c,
                Status   = 'Not Started',
                Priority = 'High'
            );
            insert t;

            // 4. Set Welcome_Email_Sent__c = true
            member.Welcome_Email_Sent__c = true;
            update member;
        }
    }

    /**
     * Checks for members who converted but haven't signed their waiver
     * after 7 days, and creates reminder tasks.
     * Called by a scheduled job (daily).
     */
    public static void runWaiverReminderJob() {
        // Query Member__c WHERE Waiver_Needed__c = true AND CreatedDate <= TODAY() - 7
        Date thresholdDate = Date.today().addDays(-7);
        List<Member__c> membersNeedingWaiver = [
            SELECT Id, Name, First_Name__c, Last_Name__c
            FROM Member__c
            WHERE Waiver_Needed__c = true
              AND CreatedDate < :thresholdDate
        ];

        // For each: create task "Waiver reminder for [Name]", send email
        List<Task> tasks = new List<Task>();
        for (Member__c m : membersNeedingWaiver) {
            tasks.add(new Task(
                WhatId   = m.Id,
                Subject  = 'Waiver reminder for ' + m.First_Name__c + ' ' + m.Last_Name__c,
                Status   = 'Not Started',
                Priority = 'Medium'
            ));
        }

        if (!tasks.isEmpty()) {
            insert tasks;
        }
    }
}