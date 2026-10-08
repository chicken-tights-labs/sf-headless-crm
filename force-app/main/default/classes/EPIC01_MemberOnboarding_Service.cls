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

    public class ConversionException extends Exception {}

    public static final String MSG_MEMBER_EXISTS      = 'Member already exists for this lead — view existing Member record';
    public static final String MSG_ALREADY_CONVERTED  = 'Lead already converted to Member — view linked Member record';
    public static final String MSG_DISQUALIFIED       = 'Cannot convert disqualified lead — change status to Qualified first';
    public static final String MSG_NO_LOCATION        = 'Cannot convert: Lead has no Franchise Location assigned';
    public static final String MSG_NO_ORIGINAL_LEAD   = 'This Member was not created from a Lead, so it cannot be unconverted';
    public static final String MSG_UNCONVERT_PROSPECT_ONLY = 'Only Prospect members can be unconverted';
    public static final String MSG_UNCONVERT_PERMISSION    = 'Only a System Administrator can unconvert a Member';

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
                   Lead_Source__c, Lead_Status__c, Converted_Member__c
            FROM Lead__c WHERE Id = :leadId
        ];

        // 1b. Guards (US-002 negative scenarios)
        if (lead.Converted_Member__c != null) {
            throw new ConversionException(MSG_MEMBER_EXISTS);
        }
        if (lead.Lead_Status__c == 'Converted') {
            throw new ConversionException(MSG_ALREADY_CONVERTED);
        }
        if (lead.Lead_Status__c == 'Unqualified') {
            // Gherkin calls this state "Disqualified"; the picklist value is "Unqualified".
            throw new ConversionException(MSG_DISQUALIFIED);
        }
        if (lead.Franchise_Location__c == null) {
            throw new ConversionException(MSG_NO_LOCATION);
        }

        // 2. Create Member__c with copied fields, Status = 'Prospect'
        Member__c newMember = new Member__c(
            Name                = lead.First_Name__c + '_' + lead.Last_Name__c,
            First_Name__c       = lead.First_Name__c,
            Last_Name__c        = lead.Last_Name__c,
            Email__c            = lead.Email__c,
            Phone__c            = lead.Phone__c,
            Home_Location__c    = lead.Franchise_Location__c,
            Referred_By__c      = lead.Referred_By__c,
            Lead_Source__c      = lead.Lead_Source__c,
            Program_Interest__c = lead.Program_Interest__c,
            Original_Lead__c    = lead.Id,
            Status__c           = 'Prospect',
            Waiver_Needed__c    = false
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
                Subject  = 'Member needs to sign waiver before payment',
                Status   = 'Not Started',
                Priority = 'High'
            );
            insert t;
        }

        // 4b. Audit trail: task to schedule the first class
        insert new Task(
            WhatId   = newMember.Id,
            Subject  = 'Schedule first class for ' + lead.First_Name__c + ' ' + lead.Last_Name__c,
            Status   = 'Not Started',
            Priority = 'Normal'
        );

        // 4c. Notify the referring member (if any)
        if (lead.Referred_By__c != null) {
            notifyReferrerOfConversion(lead.Referred_By__c, lead.First_Name__c + ' ' + lead.Last_Name__c);
        }

        // 5. Return newMember (re-query to ensure fresh data in memory)
        return [
            SELECT Id, Name, First_Name__c, Last_Name__c, Email__c, Phone__c,
                   Home_Location__c, Referred_By__c, Status__c, Waiver_Needed__c
            FROM Member__c WHERE Id = :newMember.Id
        ];
    }

    /**
     * Emails the referring member that their referral has joined.
     * Email delivery problems (e.g. deliverability disabled in a scratch org)
     * must not roll back a conversion, so they are caught and logged.
     */
    @TestVisible
    private static void notifyReferrerOfConversion(Id referrerId, String referralName) {
        List<Member__c> referrers = [SELECT Id, Email__c FROM Member__c WHERE Id = :referrerId];
        if (referrers.isEmpty() || String.isBlank(referrers[0].Email__c)) {
            return;
        }
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ referrers[0].Email__c });
        mail.setSubject('Your referral ' + referralName + ' has joined NBS Gym!');
        mail.setPlainTextBody('Your referral ' + referralName + ' has joined NBS Gym!');
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Referral notification not sent: ' + e.getMessage());
        }
    }

    /**
     * Reverses a conversion (System Administrator action).
     * Deletes the Prospect Member, restores the Lead to Qualified, clears
     * Converted_Member__c and detaches any waiver that was transferred.
     * Active members are refused: deleting a paying member is not a "reversal".
     */
    public static void unconvertMember(Id memberId) {
        if (!Schema.sObjectType.Member__c.isDeletable()) {
            throw new ConversionException(MSG_UNCONVERT_PERMISSION);
        }
        List<Member__c> members = [
            SELECT Id, Status__c, Original_Lead__c FROM Member__c WHERE Id = :memberId
        ];
        if (members.isEmpty() || members[0].Original_Lead__c == null) {
            throw new ConversionException(MSG_NO_ORIGINAL_LEAD);
        }
        Member__c member = members[0];
        if (member.Status__c != 'Prospect') {
            throw new ConversionException(MSG_UNCONVERT_PROSPECT_ONLY);
        }

        // Waivers that came over from the lead go back to lead-only.
        List<Waiver_Record__c> waivers = [
            SELECT Id, Member__c FROM Waiver_Record__c
            WHERE Member__c = :memberId AND Lead__c = :member.Original_Lead__c
        ];
        for (Waiver_Record__c w : waivers) {
            w.Member__c = null;
        }
        update waivers;

        // Lookup is Restrict-on-delete, so clear it before deleting the member.
        update new Lead__c(
            Id                  = member.Original_Lead__c,
            Lead_Status__c      = 'Qualified',
            Converted_Member__c = null
        );
        delete member;
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
        // Shared evaluation (also used by the Booking__c trigger, US-007)
        String status = waiverStatusByMember(new Set<Id>{ memberId }).get(memberId);

        if (status == 'Signed') {
            return new PaymentGateResult(true, null, 'Signed');
        }
        if (status == 'Missing') {
            return new PaymentGateResult(false, 'Please sign your waiver first', 'Missing');
        }
        if (status == 'Pending') {
            return new PaymentGateResult(false, 'Waiver pending signature', 'Pending');
        }
        if (status == 'Revoked') {
            return new PaymentGateResult(false, 'Waiver has been revoked', 'Revoked');
        }
        if (status == 'Expired') {
            return new PaymentGateResult(false, 'Your waiver has expired', 'Expired');
        }
        return new PaymentGateResult(false, 'Unable to determine waiver status', 'Unknown');
    }

    /**
     * Single source of truth for "does this member have a valid waiver?".
     * A member is 'Signed' (valid) if ANY of their waivers is Signed and not expired.
     * Otherwise the status of their most recent waiver is reported:
     * Expired, Pending, Revoked, Unknown, or Missing (no waiver at all).
     * Bulk-safe: one query for any number of members.
     * Used by the payment gate (US-003) and the Booking__c trigger (US-007).
     */
    public static Map<Id, String> waiverStatusByMember(Set<Id> memberIds) {
        Map<Id, String> result = new Map<Id, String>();
        for (Id memberId : memberIds) {
            result.put(memberId, 'Missing');
        }
        Set<Id> seen = new Set<Id>();
        Set<Id> hasValid = new Set<Id>();
        for (Waiver_Record__c w : [
            SELECT Member__c, Status__c, Expiration_Date__c
            FROM Waiver_Record__c
            WHERE Member__c IN :memberIds
            ORDER BY CreatedDate DESC
        ]) {
            if (hasValid.contains(w.Member__c)) {
                continue; // any valid waiver wins
            }
            if (w.Status__c == 'Signed'
                && (w.Expiration_Date__c == null || w.Expiration_Date__c >= Date.today())) {
                hasValid.add(w.Member__c);
                result.put(w.Member__c, 'Signed');
                continue;
            }
            if (!seen.add(w.Member__c)) {
                continue; // otherwise report the most recent (first seen) waiver's status
            }
            String status;
            if (w.Status__c == 'Signed') {
                Boolean expired = w.Expiration_Date__c != null && w.Expiration_Date__c < Date.today();
                status = expired ? 'Expired' : 'Signed';
            } else if (w.Status__c == 'Pending' || w.Status__c == 'Revoked') {
                status = w.Status__c;
            } else {
                status = 'Unknown';
            }
            result.put(w.Member__c, status);
        }
        return result;
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
        sendWelcomeEmails(new Set<Id>{ memberId });
    }

    // Sent emails cannot be read back in Apex tests, so bodies are captured here for assertions.
    @TestVisible private static List<String> welcomeBodiesForTest = new List<String>();
    // Test hook: simulates the email send failing (Email__c is required and format-checked on Member__c).
    @TestVisible private static Boolean simulateWelcomeSendFailure = false;

    private static final Pattern EMAIL_FORMAT = Pattern.compile('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');

    /**
     * Bulk-safe welcome workflow. For each member whose Welcome_Email_Sent__c is false:
     *  - success: sends the welcome email, creates the orientation task (due in 7 days),
     *    sets Welcome_Email_Sent__c = true
     *  - failure (blank/invalid address or send error): creates the admin task
     *    "Welcome email failed for <name> — verify email address" and leaves the flag false
     * Members already flagged are skipped, so the email and task never repeat.
     */
    public static void sendWelcomeEmails(Set<Id> memberIds) {
        List<Member__c> members = [
            SELECT Id, First_Name__c, Last_Name__c, Email__c, Membership_Tier__c, Date_of_Birth__c,
                   Guardian_Name__c, Welcome_Email_Sent__c, Referred_By__c, Referred_By__r.Name,
                   Home_Location__r.Name, Home_Location__r.Phone__c
            FROM Member__c
            WHERE Id IN :memberIds AND Welcome_Email_Sent__c = false
        ];

        List<Member__c> toSend = new List<Member__c>();
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        List<Task> tasks = new List<Task>();
        List<Member__c> sentFlags = new List<Member__c>();

        for (Member__c m : members) {
            if (String.isBlank(m.Email__c) || !EMAIL_FORMAT.matcher(m.Email__c.trim()).matches()) {
                tasks.add(welcomeFailedTask(m));
                continue;
            }
            toSend.add(m);
            mails.add(buildWelcomeEmail(m));
        }

        if (!mails.isEmpty()) {
            List<Messaging.SendEmailResult> results;
            try {
                if (simulateWelcomeSendFailure) {
                    throw new System.EmailException('Simulated send failure');
                }
                results = Messaging.sendEmail(mails, false);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Welcome email send failed: ' + e.getMessage());
            }
            for (Integer i = 0; i < toSend.size(); i++) {
                Member__c m = toSend[i];
                if (results != null && results[i].isSuccess()) {
                    tasks.add(new Task(
                        WhatId       = m.Id,
                        Subject      = 'Schedule facility orientation for ' + m.First_Name__c + ' ' + m.Last_Name__c,
                        Status       = 'Not Started',
                        Priority     = 'High',
                        ActivityDate = Date.today().addDays(7)
                    ));
                    sentFlags.add(new Member__c(Id = m.Id, Welcome_Email_Sent__c = true));
                    if (m.Referred_By__c != null) {
                        notifyReferrerOfConversion(m.Referred_By__c, m.First_Name__c + ' ' + m.Last_Name__c);
                    }
                } else {
                    tasks.add(welcomeFailedTask(m));
                }
            }
        }

        if (!tasks.isEmpty()) {
            insert tasks;
        }
        if (!sentFlags.isEmpty()) {
            update sentFlags;
        }
    }

    private static Task welcomeFailedTask(Member__c m) {
        return new Task(
            WhatId   = m.Id,
            Subject  = 'Welcome email failed for ' + m.First_Name__c + ' ' + m.Last_Name__c
                       + ' — verify email address',
            Status   = 'Not Started',
            Priority = 'High'
        );
    }

    private static Boolean isMinor(Member__c m) {
        return m.Date_of_Birth__c != null && m.Date_of_Birth__c > Date.today().addYears(-18);
    }

    private static Messaging.SingleEmailMessage buildWelcomeEmail(Member__c m) {
        Boolean showGuardian = String.isNotBlank(m.Guardian_Name__c) || isMinor(m);
        String greetingName = String.isNotBlank(m.Guardian_Name__c) ? m.Guardian_Name__c : m.First_Name__c;
        String tier = String.isBlank(m.Membership_Tier__c) ? 'your membership' : m.Membership_Tier__c;
        String body = 'Hi ' + greetingName + ',\n\n'
            + 'Welcome to NBS Gym! You are now an active member on the ' + tier + ' plan.\n\n'
            + 'Class schedule: see your member portal or ask the front desk for this week\'s schedule.\n'
            + 'Next step: we will contact you to schedule a facility orientation within 7 days.\n';
        if (m.Home_Location__r != null) {
            body += '\nYour gym: ' + m.Home_Location__r.Name
                 + (String.isNotBlank(m.Home_Location__r.Phone__c) ? ' (' + m.Home_Location__r.Phone__c + ')' : '') + '\n';
        }
        if (showGuardian) {
            body += '\nParent/Guardian Information\n'
                 + 'This membership is for a minor' + (String.isNotBlank(m.Guardian_Name__c)
                      ? '; guardian on file: ' + m.Guardian_Name__c : '')
                 + '. A parent or guardian must stay on file and sign all waivers.\n';
        }
        if (m.Referred_By__c != null && m.Referred_By__r != null) {
            body += '\nThanks to ' + m.Referred_By__r.Name.replace('_', ' ') + ' for the referral!\n';
        }
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ m.Email__c.trim() });
        mail.setSubject('Welcome to NBS Gym, ' + m.First_Name__c + '!');
        mail.setPlainTextBody(body);
        welcomeBodiesForTest.add(body);
        return mail;
    }

    /**
     * Checks for members who converted but haven't signed their waiver
     * after 7 days, and creates reminder tasks.
     * Called by a scheduled job (daily).
     */
    public static void runWaiverReminderJob() {
        // Members flagged at conversion who are still unsigned after 7 days
        Datetime threshold = Datetime.now().addDays(-7);
        List<Member__c> candidates = [
            SELECT Id, First_Name__c, Last_Name__c, Email__c
            FROM Member__c
            WHERE Waiver_Needed__c = true
              AND CreatedDate <= :threshold
            LIMIT 200
        ];
        if (candidates.isEmpty()) {
            return;
        }
        Set<Id> candidateIds = new Map<Id, Member__c>(candidates).keySet();

        // Skip members who have since signed a valid waiver
        Map<Id, String> waiverStatus = waiverStatusByMember(candidateIds);

        // Skip members who already have a reminder task (job runs daily)
        Set<Id> alreadyReminded = new Set<Id>();
        for (Task t : [
            SELECT WhatId FROM Task
            WHERE WhatId IN :candidateIds AND Subject LIKE 'Waiver reminder for %'
        ]) {
            alreadyReminded.add(t.WhatId);
        }

        List<Task> tasks = new List<Task>();
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (Member__c m : candidates) {
            if (waiverStatus.get(m.Id) == 'Signed' || alreadyReminded.contains(m.Id)) {
                continue;
            }
            tasks.add(new Task(
                WhatId   = m.Id,
                Subject  = 'Waiver reminder for ' + m.First_Name__c + ' ' + m.Last_Name__c,
                Status   = 'Not Started',
                Priority = 'Medium'
            ));
            if (String.isNotBlank(m.Email__c) && EMAIL_FORMAT.matcher(m.Email__c.trim()).matches()) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ m.Email__c.trim() });
                mail.setSubject('Friendly reminder: Your NBS Gym waiver is still pending');
                mail.setPlainTextBody('Hi ' + m.First_Name__c + ',\n\nYour NBS Gym waiver is still pending. '
                    + 'Please sign it before your first class or payment.\n');
                mails.add(mail);
            }
        }
        if (!tasks.isEmpty()) {
            insert tasks;
        }
        if (!mails.isEmpty()) {
            try {
                Messaging.sendEmail(mails, false);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Waiver reminder email failed: ' + e.getMessage());
            }
        }
    }

    /**
     * Called by the Member__c status trigger when members transition to Active.
     * Single place to hang activation work (welcome workflow; referral code, US-006).
     */
    public static void handleActivation(Set<Id> memberIds) {
        sendWelcomeEmails(memberIds);
    }
}