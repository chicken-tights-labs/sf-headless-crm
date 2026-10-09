/**
 * EPIC01-US-003: invocable so the waiver-signed record-triggered Flow can email
 * the member. Why Apex: send failures must be caught so the confirmation Task
 * the Flow already created is not rolled back (same pattern as conversion email).
 */
public with sharing class EPIC01_WaiverConfirmed_Action {

    public class Request {
        @InvocableVariable(required=true) public Id memberId;
    }

    @InvocableMethod(label='Notify Waiver Confirmed' description='EPIC01-US-003')
    public static void notify(List<Request> requests) {
        for (Request req : requests) {
            EPIC01_MemberOnboarding_Service.notifyWaiverConfirmed(req.memberId);
        }
    }
}
