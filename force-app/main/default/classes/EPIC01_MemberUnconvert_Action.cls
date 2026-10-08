/**
 * EPIC01-US-002: invocable wrapper for the admin "Unconvert" screen flow.
 */
public with sharing class EPIC01_MemberUnconvert_Action {

    public class Request {
        @InvocableVariable(required=true) public Id memberId;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Unconvert Member' description='EPIC01-US-002 admin reversal')
    public static List<Result> unconvert(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            Savepoint sp = Database.setSavepoint();
            try {
                EPIC01_MemberOnboarding_Service.unconvertMember(req.memberId);
                r.success = true;
                r.message = 'Member removed and Lead restored to Qualified';
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
