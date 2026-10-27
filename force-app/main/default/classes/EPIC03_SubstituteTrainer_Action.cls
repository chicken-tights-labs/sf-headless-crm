/**
 * EPIC03-US-T010: record a substitute without changing the assigned trainer.
 * Why Apex: a failed email must not undo the substitute, same as referral notices.
 */
public with sharing class EPIC03_SubstituteTrainer_Action {
  public static final String MSG_REQUIRED = 'A class is required.';
  public static final String MSG_NOT_FOUND = 'This class could not be found.';
  public static final String MSG_CANCELLED = 'Cancelled classes cannot be covered.';
  public static final String MSG_COMPLETED = 'Completed classes cannot be covered.';
  public static final String MSG_ALREADY_ASSIGNED = 'You are already the assigned trainer for this class.';
  public static final String MSG_ALREADY_SUBSTITUTE = 'You are already the substitute for this class.';
  public static final String MSG_TAKEN = 'This class already has a substitute.';
  public static final String MSG_OK = 'You are the substitute. The assigned trainer was emailed.';
  public static final String MSG_OK_NO_EMAIL = 'You are the substitute. The assigned trainer has no email, so no notice was sent.';
  public static final String MSG_OK_NO_TRAINER = 'You are the substitute. This class has no assigned trainer to notify.';
  public static final String MSG_OK_EMAIL_FAILED = 'You are the substitute. The notice to the assigned trainer could not be sent.';

  public class Request {
    @InvocableVariable(required=true)
    public Id sessionId;
  }

  public class Result {
    @InvocableVariable
    public Boolean success;
    @InvocableVariable
    public String message;
  }

  @InvocableMethod(label='Substitute for Class' description='EPIC03-US-T010')
  public static List<Result> substitute(List<Request> requests) {
    List<Result> results = new List<Result>();
    for (Request req : requests) {
      results.add(substituteOne(req == null ? null : req.sessionId));
    }
    return results;
  }

  @TestVisible
  private static Result substituteOne(Id sessionId) {
    Result result = new Result();
    if (sessionId == null) {
      result.success = false;
      result.message = MSG_REQUIRED;
      return result;
    }

    List<Scheduled_Session__c> sessions = [
      SELECT
        Id,
        Name,
        Start_Time__c,
        Session_Status__c,
        Assigned_Trainer__c,
        Substitute_Trainer__c,
        Assigned_Trainer__r.Email,
        Assigned_Trainer__r.Name
      FROM Scheduled_Session__c
      WHERE Id = :sessionId
      LIMIT 1
    ];
    if (sessions.isEmpty()) {
      result.success = false;
      result.message = MSG_NOT_FOUND;
      return result;
    }

    Scheduled_Session__c session = sessions[0];
    Id me = UserInfo.getUserId();
    if (session.Session_Status__c == 'Cancelled') {
      return refused(MSG_CANCELLED);
    }
    if (session.Session_Status__c == 'Completed') {
      return refused(MSG_COMPLETED);
    }
    if (session.Assigned_Trainer__c == me) {
      return refused(MSG_ALREADY_ASSIGNED);
    }
    if (session.Substitute_Trainer__c == me) {
      return refused(MSG_ALREADY_SUBSTITUTE);
    }
    if (session.Substitute_Trainer__c != null) {
      return refused(MSG_TAKEN);
    }

    update new Scheduled_Session__c(
      Id = session.Id,
      Substitute_Trainer__c = me
    );

    result.success = true;
    result.message = notifyOriginal(session);
    return result;
  }

  private static Result refused(String message) {
    Result result = new Result();
    result.success = false;
    result.message = message;
    return result;
  }

  private static String notifyOriginal(Scheduled_Session__c session) {
    if (session.Assigned_Trainer__c == null) {
      return MSG_OK_NO_TRAINER;
    }
    if (String.isBlank(session.Assigned_Trainer__r.Email)) {
      return MSG_OK_NO_EMAIL;
    }

    String whenText = session.Start_Time__c == null
      ? 'a time not set yet'
      : session.Start_Time__c.format();
    String body =
      UserInfo.getName() +
      ' is covering ' +
      session.Name +
      ' on ' +
      whenText +
      '. You remain the assigned trainer.';

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(new List<String>{ session.Assigned_Trainer__r.Email });
    mail.setSubject('Substitute covering your class');
    mail.setPlainTextBody(body);
    mail.setSaveAsActivity(false);
    try {
      Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
      return MSG_OK;
    } catch (Exception e) {
      return MSG_OK_EMAIL_FAILED;
    }
  }
}
