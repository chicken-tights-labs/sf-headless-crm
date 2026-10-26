/**
 * EPIC03-US-T001: trainer view of this week's assigned classes.
 * Why Apex: filters Scheduled_Session__c to the running user, THIS_WEEK,
 * and returns booked counts without a separate trainer app.
 */
public with sharing class EPIC03_TrainerSchedule_Controller {
  public class SessionRow {
    @AuraEnabled
    public Id sessionId;
    @AuraEnabled
    public String sessionName;
    @AuraEnabled
    public String sessionUrl;
    @AuraEnabled
    public Datetime startTime;
    @AuraEnabled
    public Datetime endTime;
    @AuraEnabled
    public String locationName;
    @AuraEnabled
    public Integer bookedCount;
    @AuraEnabled
    public Decimal capacity;
  }

  @AuraEnabled(cacheable=true)
  public static List<SessionRow> getMyWeekSessions() {
    Id trainerId = UserInfo.getUserId();

    List<Scheduled_Session__c> sessions = [
      SELECT
        Id,
        Name,
        Start_Time__c,
        End_Time__c,
        Max_Capacity__c,
        Franchise_Location__r.Name
      FROM Scheduled_Session__c
      WHERE
        Assigned_Trainer__c = :trainerId
        AND Start_Time__c = THIS_WEEK
        AND Session_Status__c != 'Cancelled'
      WITH USER_MODE
      ORDER BY Start_Time__c ASC NULLS LAST
    ];

    Map<Id, Integer> bookedBySession = bookedCounts(sessions);

    List<SessionRow> rows = new List<SessionRow>();
    for (Scheduled_Session__c session : sessions) {
      SessionRow row = new SessionRow();
      row.sessionId = session.Id;
      row.sessionName = session.Name;
      row.sessionUrl = '/' + session.Id;
      row.startTime = session.Start_Time__c;
      row.endTime = session.End_Time__c;
      row.locationName = session.Franchise_Location__r == null
        ? null
        : session.Franchise_Location__r.Name;
      row.bookedCount = bookedBySession.containsKey(session.Id)
        ? bookedBySession.get(session.Id)
        : 0;
      row.capacity = session.Max_Capacity__c;
      rows.add(row);
    }
    return rows;
  }

  private static Map<Id, Integer> bookedCounts(
    List<Scheduled_Session__c> sessions
  ) {
    Map<Id, Integer> counts = new Map<Id, Integer>();
    if (sessions.isEmpty()) {
      return counts;
    }

    Set<Id> sessionIds = new Set<Id>();
    for (Scheduled_Session__c session : sessions) {
      sessionIds.add(session.Id);
    }

    for (AggregateResult ar : [
      SELECT Scheduled_Session__c sessionId, COUNT(Id) booked
      FROM Booking__c
      WHERE Scheduled_Session__c IN :sessionIds AND Status__c != 'Cancelled'
      WITH USER_MODE
      GROUP BY Scheduled_Session__c
    ]) {
      counts.put((Id) ar.get('sessionId'), Integer.valueOf(ar.get('booked')));
    }
    return counts;
  }
}
