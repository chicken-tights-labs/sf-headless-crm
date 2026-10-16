/**
 * EPIC04-US-F003: invocable wrapper so the Renew Membership screen flow can
 * extend dates and take payment without calling processPayment.
 * Why Apex: renewal writes Member expiry, Payment_Transaction, and optional
 * retry task while skipping welcome email and referral award.
 */
public with sharing class EPIC04_RenewMembership_Action {
  public class Request {
    @InvocableVariable(required=true)
    public Id memberId;
    @InvocableVariable(required=true)
    public String amount;
    @InvocableVariable(required=true)
    public String paymentMethod;
  }

  public class Result {
    @InvocableVariable
    public Boolean success;
    @InvocableVariable
    public String message;
  }

  @InvocableMethod(label='Renew Membership' description='EPIC04-US-F003')
  public static List<Result> renew(List<Request> requests) {
    List<Result> results = new List<Result>();
    for (Request req : requests) {
      Result r = new Result();
      Savepoint sp = Database.setSavepoint();
      try {
        Boolean ok = EPIC01_MemberOnboarding_Service.renewMembership(
          req.memberId,
          req.amount,
          req.paymentMethod
        );
        r.success = ok;
        r.message = ok
          ? EPIC01_MemberOnboarding_Service.MSG_RENEW_OK
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
