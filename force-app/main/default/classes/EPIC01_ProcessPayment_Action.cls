/**
 * EPIC01-US-004: invocable wrapper so the "Process Membership Payment" screen
 * flow can take payment and show gate / decline messages.
 * Why Apex: payment writes Member, Payment_Transaction, Tasks, referral, and
 * emails in one transaction against a simulated processor.
 */
public with sharing class EPIC01_ProcessPayment_Action {

    public class Request {
        @InvocableVariable(required=true) public Id memberId;
        @InvocableVariable(required=true) public String amount;
        @InvocableVariable(required=true) public String paymentMethod;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Process Membership Payment' description='EPIC01-US-004')
    public static List<Result> pay(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            Savepoint sp = Database.setSavepoint();
            try {
                Boolean ok = EPIC01_MemberOnboarding_Service.processPayment(
                    req.memberId, req.amount, req.paymentMethod
                );
                r.success = ok;
                r.message = ok
                    ? EPIC01_MemberOnboarding_Service.MSG_PAYMENT_OK
                    : EPIC01_MemberOnboarding_Service.MSG_PAYMENT_FAILED;
            } catch (Exception e) {
                Database.rollback(sp);
                r.success = false;
                r.message = e.getMessage();
            }
            results.add(r);
        }
        return results;
    }
}
