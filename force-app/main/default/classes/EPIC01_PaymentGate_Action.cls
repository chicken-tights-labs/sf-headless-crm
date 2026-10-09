/**
 * EPIC01-US-003: invocable wrapper so the "Select Membership Tier" screen flow
 * can read the waiver payment gate without a raw Apex error.
 * Why Apex: the gate queries related Waiver_Record__c rows (a Validation Rule cannot).
 */
public with sharing class EPIC01_PaymentGate_Action {

    public class Request {
        @InvocableVariable(required=true) public Id memberId;
    }

    public class Result {
        @InvocableVariable public Boolean canProceed;
        @InvocableVariable public String message;
        @InvocableVariable public String waiverStatus;
    }

    @InvocableMethod(label='Check Payment Gate' description='EPIC01-US-003 waiver gate before payment')
    public static List<Result> check(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            EPIC01_MemberOnboarding_Service.PaymentGateResult gate =
                EPIC01_MemberOnboarding_Service.attemptProceedToPayment(req.memberId);
            r.canProceed = gate.canProceed;
            r.waiverStatus = gate.waiverStatus;
            r.message = gate.canProceed
                ? EPIC01_MemberOnboarding_Service.MSG_WAIVER_VALID
                : gate.errorMessage;
            results.add(r);
        }
        return results;
    }
}
