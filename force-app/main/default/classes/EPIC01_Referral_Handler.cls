/**
 * EPIC01-US-006: Referral Program logic.
 *
 * Lifecycle of a Referral_Reward__c:
 *   Code Used        - a lead was created with a valid referral code (after insert on Lead__c)
 *   Member Created   - that lead was converted to a Member (convertLeadToMember)
 *   Payment Completed- the referred member's first payment completed (processPayment)
 *   Reward Claimed   - the referrer was rewarded; or Cancelled when the referrer is no longer
 *                      eligible (Cancelled / Lapsed / Suspended). Attribution stays on the lead
 *                      and member either way.
 */
public with sharing class EPIC01_Referral_Handler {

    public static final String MSG_SELF = 'You cannot refer yourself';
    public static final String MSG_NOT_FOUND = 'Referral code not found — continuing without attribution';
    public static final String MSG_ALREADY_MEMBER = 'Already a member — referral not applied';

    // Referrer statuses that keep attribution but earn no reward.
    private static final Set<String> INELIGIBLE_REFERRER_STATUSES = new Set<String>{
        'Cancelled', 'Lapsed', 'Suspended'
    };

    private static final String CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    // ------------------------------------------------------------------
    // Lead__c triggers
    // ------------------------------------------------------------------

    /**
     * Before insert (runs after the attribution flow has set Referred_By__c):
     *  - lead email equals the referrer's email  -> blocked with MSG_SELF
     *  - lead email already belongs to a Member  -> referral dropped, existing member linked
     */
    public static void beforeInsert(List<Lead__c> leads) {
        Set<Id> referrerIds = new Set<Id>();
        Set<String> emails = new Set<String>();
        for (Lead__c l : leads) {
            if (l.Referred_By__c != null && String.isNotBlank(l.Email__c)) {
                referrerIds.add(l.Referred_By__c);
                emails.add(l.Email__c.toLowerCase());
            }
        }
        if (referrerIds.isEmpty()) {
            return;
        }
        Map<Id, Member__c> referrers = new Map<Id, Member__c>(
            [SELECT Id, Email__c FROM Member__c WHERE Id IN :referrerIds]
        );
        Map<String, Id> memberByEmail = new Map<String, Id>();
        for (Member__c m : [SELECT Id, Email__c FROM Member__c WHERE Email__c IN :emails]) {
            memberByEmail.put(m.Email__c.toLowerCase(), m.Id);
        }
        for (Lead__c l : leads) {
            if (l.Referred_By__c == null || String.isBlank(l.Email__c)) {
                continue;
            }
            String email = l.Email__c.toLowerCase();
            Member__c referrer = referrers.get(l.Referred_By__c);
            if (referrer != null && String.isNotBlank(referrer.Email__c)
                && referrer.Email__c.toLowerCase() == email) {
                l.addError(MSG_SELF);
            } else if (memberByEmail.containsKey(email)) {
                l.Referred_By__c = null;
                l.Converted_Member__c = memberByEmail.get(email);
                l.Notes__c = String.isBlank(l.Notes__c) ? MSG_ALREADY_MEMBER : l.Notes__c + '\n' + MSG_ALREADY_MEMBER;
            }
        }
    }

    /**
     * After insert: count the attempt on the referrer and open a "Code Used" reward record.
     */
    public static void afterInsert(List<Lead__c> leads) {
        Map<Id, Integer> attemptsByReferrer = new Map<Id, Integer>();
        List<Referral_Reward__c> rewards = new List<Referral_Reward__c>();
        for (Lead__c l : leads) {
            if (l.Referred_By__c == null) {
                continue;
            }
            Integer n = attemptsByReferrer.containsKey(l.Referred_By__c) ? attemptsByReferrer.get(l.Referred_By__c) : 0;
            attemptsByReferrer.put(l.Referred_By__c, n + 1);
            rewards.add(new Referral_Reward__c(
                Referring_Member__c = l.Referred_By__c,
                Referred_Lead__c    = l.Id,
                Status__c           = 'Code Used',
                Date_Attributed__c  = System.now()
            ));
        }
        if (rewards.isEmpty()) {
            return;
        }
        List<Member__c> referrers = [
            SELECT Id, Referral_Attempts__c FROM Member__c WHERE Id IN :attemptsByReferrer.keySet()
        ];
        for (Member__c r : referrers) {
            Decimal current = r.Referral_Attempts__c == null ? 0 : r.Referral_Attempts__c;
            r.Referral_Attempts__c = current + attemptsByReferrer.get(r.Id);
        }
        update referrers;
        insert rewards;
    }

    // ------------------------------------------------------------------
    // Lifecycle
    // ------------------------------------------------------------------

    /** Lead converted: link the reward to the new member and move it to "Member Created". */
    public static void markMemberCreated(Id leadId, Id memberId) {
        List<Referral_Reward__c> rewards = [
            SELECT Id FROM Referral_Reward__c
            WHERE Referred_Lead__c = :leadId AND Status__c = 'Code Used'
        ];
        for (Referral_Reward__c r : rewards) {
            r.Referred_Member__c = memberId;
            r.Status__c = 'Member Created';
        }
        update rewards;
    }

    /**
     * First payment completed: reward the referrer. Idempotent per referred member -
     * a second call (or a retried payment) never awards twice.
     */
    public static void awardReward(Id referringMemberId, Id referredMemberId) {
        List<Referral_Reward__c> existing = [
            SELECT Id, Status__c FROM Referral_Reward__c
            WHERE Referring_Member__c = :referringMemberId AND Referred_Member__c = :referredMemberId
            ORDER BY CreatedDate ASC
        ];
        Referral_Reward__c reward;
        for (Referral_Reward__c r : existing) {
            if (r.Status__c == 'Reward Claimed' || r.Status__c == 'Cancelled') {
                return;
            }
            if (reward == null) {
                reward = r;
            }
        }
        if (reward == null) {
            reward = new Referral_Reward__c(
                Referring_Member__c = referringMemberId,
                Referred_Member__c  = referredMemberId,
                Date_Attributed__c  = System.now()
            );
        }

        Member__c referrer = [
            SELECT Id, Status__c, Membership_Tier__c, Classes_Remaining__c, Account_Credit__c
            FROM Member__c WHERE Id = :referringMemberId
        ];

        if (INELIGIBLE_REFERRER_STATUSES.contains(referrer.Status__c)) {
            reward.Status__c = 'Cancelled';
            upsert reward;
            return;
        }

        Integer currentClasses = referrer.Classes_Remaining__c == null ? 0 : (Integer) referrer.Classes_Remaining__c;
        Decimal currentCredit = referrer.Account_Credit__c == null ? 0 : referrer.Account_Credit__c;
        referrer.Classes_Remaining__c = currentClasses + 1;
        reward.Reward_Type__c = 'Class Credit';
        reward.Reward_Amount__c = 1;
        if (referrer.Membership_Tier__c == 'Monthly Unlimited ($129)'
            || referrer.Membership_Tier__c == 'Annual Prepaid ($99/mo)') {
            referrer.Account_Credit__c = currentCredit + 10;
            reward.Reward_Type__c = 'Account Credit';
            reward.Reward_Amount__c = 10;
        }
        update referrer;

        reward.Status__c = 'Reward Claimed';
        reward.Date_Claimed__c = System.now();
        upsert reward;
    }

    // ------------------------------------------------------------------
    // Code generation
    // ------------------------------------------------------------------

    /**
     * Gives every listed Member that has no code a unique 8-character code:
     * 3-char initials + 5 random characters. Existing codes are never changed.
     * Bulk-safe: one uniqueness query per round, up to 5 rounds.
     */
    public static void generateCodes(Set<Id> memberIds) {
        List<Member__c> members = [
            SELECT Id, First_Name__c, Last_Name__c, Referral_Attempts__c
            FROM Member__c
            WHERE Id IN :memberIds AND Referral_Code__c = null
        ];
        if (members.isEmpty()) {
            return;
        }
        Set<String> used = new Set<String>();
        List<Member__c> pending = members;
        for (Integer round = 0; round < 5 && !pending.isEmpty(); round++) {
            Map<Id, String> candidates = new Map<Id, String>();
            for (Member__c m : pending) {
                candidates.put(m.Id, initials(m) + randomSuffix(5));
            }
            Set<String> taken = new Set<String>();
            for (Member__c other : [SELECT Referral_Code__c FROM Member__c WHERE Referral_Code__c IN :candidates.values()]) {
                taken.add(other.Referral_Code__c);
            }
            List<Member__c> retry = new List<Member__c>();
            for (Member__c m : pending) {
                String code = candidates.get(m.Id);
                if (taken.contains(code) || used.contains(code)) {
                    retry.add(m);
                } else {
                    used.add(code);
                    m.Referral_Code__c = code;
                    if (m.Referral_Attempts__c == null) {
                        m.Referral_Attempts__c = 0;
                    }
                }
            }
            pending = retry;
        }
        List<Member__c> done = new List<Member__c>();
        for (Member__c m : members) {
            if (m.Referral_Code__c != null) {
                done.add(m);
            }
        }
        update done;
    }

    private static String initials(Member__c m) {
        String s = '';
        if (String.isNotBlank(m.First_Name__c)) {
            s += m.First_Name__c.substring(0, 1).toUpperCase();
        }
        if (String.isNotBlank(m.Last_Name__c)) {
            s += m.Last_Name__c.substring(0, 1).toUpperCase();
        }
        while (s.length() < 3) {
            s += 'X';
        }
        return s.left(3);
    }

    private static String randomSuffix(Integer len) {
        String s = '';
        for (Integer i = 0; i < len; i++) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), CODE_CHARS.length());
            s += CODE_CHARS.substring(idx, idx + 1);
        }
        return s;
    }
}
