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
 *
 * TODO: This is a SKELETON — implement the method bodies.
 * The test class (EPIC01_MemberOnboarding_Test.cls) defines the contract.
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
        // TODO: Implement
        // 1. Query Lead__c (with Franchise_Location__c, Referred_By__c, etc.)
        // 2. Create Member__c with copied fields, Status = 'Prospect'
        // 3. Set Lead.Converted_Member__c = newMember.Id
        // 4. Set Lead.Lead_Status__c = 'Converted'
        // 5. Query Waiver_Record__c WHERE Lead__c = :leadId AND Status = 'Signed' AND (Expiration IS NULL OR >= TODAY)
        //    → If found: set Waiver_Record__c.Member__c = newMember.Id
        //    → If not found: create task "Member needs to sign waiver"
        // 6. Return newMember
        return null;
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
        // TODO: Implement
        // 1. Query Member__c (with Home_Location__c)
        // 2. Query Waiver_Record__c WHERE Member__c = :memberId
        // 3. Validate: Status = 'Signed' AND (Expiration_Date__c IS NULL OR Expiration_Date__c >= TODAY)
        // 4. If valid → return PaymentGateResult(true, null, 'Signed')
        // 5. If missing → return PaymentGateResult(false, 'Please sign your waiver first', 'Missing')
        // 6. If expired → return PaymentGateResult(false, 'Your waiver has expired', 'Expired')
        // 7. If pending → return PaymentGateResult(false, 'Waiver pending signature', 'Pending')
        // 8. If revoked → return PaymentGateResult(false, 'Waiver has been revoked', 'Revoked')
        return null;
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

    /**
     * Processes a payment for a Member's selected tier.
     * Sets membership dates, updates Classes_Remaining__c,
     * transitions Status from 'Prospect' → 'Active',
     * creates Payment_Transaction__c, triggers welcome email.
     *
     * Returns true if payment succeeded, false if failed.
     */
    public static Boolean processPayment(Id memberId, String amount, String paymentMethod) {
        // TODO: Implement
        // 1. Query Member__c (with Membership_Tier__c, Home_Location__c, Referred_By__c)
        // 2. Call payment processor (Stripe) — or simulate success/failure
        // 3. On success:
        //    a. Set Status__c = 'Active'
        //    b. Set Start_Date__c = TODAY
        //    c. Set Expiry_Date__c based on tier:
        //       - Monthly Unlimited → +30 days
        //       - Annual Prepaid → +365 days
        //       - Drop-In → no dates (pay-per-class)
        //       - Punch Card → +180 days, Classes_Remaining__c = 10
        //    d. Create Payment_Transaction__c (Amount, Method, Status='Completed')
        //    e. Set Is_Recurring__c = true for recurring tiers
        //    f. If Referred_By__c is set → trigger referral reward (US-006)
        //    g. Trigger welcome email + orientation task (US-005)
        // 4. On failure:
        //    a. Create Payment_Transaction__c with Status='Failed'
        //    b. Create task "Retry payment for [Member Name]"
        return false;
    }

    /**
     * Calculates the final payment amount after applying any
     * referral friend discount (50% off first pack).
     */
    public static Decimal calculatePaymentWithReferralDiscount(Id memberId, String originalAmount) {
        // TODO: Implement
        // 1. Query Member__c (with Referred_By__c)
        // 2. If Referred_By__c is set → return Decimal.valueOf(originalAmount) * 0.50
        // 3. Otherwise → return Decimal.valueOf(originalAmount)
        return Decimal.valueOf(originalAmount);
    }

    // =====================================================
    // US-006: Referral Program
    // =====================================================

    /**
     * Generates a unique 8-character referral code for a Member.
     * Format: 3 initials + 4-digit number + 1 checksum char
     * e.g., SAM0KA00
     */
    public static void generateReferralCode(Id memberId) {
        // TODO: Implement
        // 1. Query Member__c
        // 2. Generate code: FirstInitial + LastInitial + random 4 digits + checksum
        // 3. Check uniqueness — if collision, regenerate
        // 4. Set Referral_Code__c and Referral_Attempts__c = 0
    }

    /**
     * Looks up a Member by their referral code.
     * Returns null if not found.
     */
    public static Member__c lookupReferralCode(String referralCode) {
        // TODO: Implement
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
        // TODO: Implement
        // Check Member__c WHERE Email__c = :email AND Referred_By__c = :referrerId
        // Also check Lead__c WHERE Email__c = :email AND Referred_By__c = :referrerId
        return false;
    }

    /**
     * Awards the referral reward to the referring member.
     * Called when the referred member's first payment completes.
     */
    public static void awardReferralReward(Id referringMemberId, Id referredMemberId) {
        // TODO: Implement
        // 1. Query referring Member__c (with Membership_Tier__c, Classes_Remaining__c, Account_Credit__c)
        // 2. Determine reward type:
        //    - Class pack tier → Classes_Remaining__c += 1
        //    - Unlimited/Student/Military tier → Account_Credit__c += 10
        //    - Drop-in → Account_Credit__c += 10
        // 3. Create Referral_Reward__c record (Status = 'Reward Claimed')
        // 4. Send notification email to referrer
    }

    // =====================================================
    // US-005: Welcome Workflow Helpers
    // =====================================================

    /**
     * Fires the welcome email + creates orientation task.
     * Called when Member Status transitions to 'Active'.
     */
    public static void sendWelcomeEmail(Id memberId) {
        // TODO: Implement
        // 1. Check Welcome_Email_Sent__c == false
        // 2. Send email template 'NBS_Gym_Welcome' to member
        // 3. Create Task: "Schedule facility orientation for [Member Name]"
        // 4. Set Welcome_Email_Sent__c = true
    }

    /**
     * Checks for members who converted but haven't signed their waiver
     * after 7 days, and creates reminder tasks.
     * Called by a scheduled job (daily).
     */
    public static void runWaiverReminderJob() {
        // TODO: Implement
        // Query Member__c WHERE Waiver_Needed__c = true AND CreatedDate <= TODAY() - 7
        // For each: create task "Waiver reminder for [Name]", send email
    }
}
