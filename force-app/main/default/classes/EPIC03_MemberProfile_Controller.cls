/**
 * EPIC03-US-T007: read-only trainer member profile.
 * Why Apex: returns a fixed trainer-facing field set and includes
 * Medical_Notes__c only when FLS allows (US-T009 permset).
 */
public with sharing class EPIC03_MemberProfile_Controller {
  public class ProfileView {
    @AuraEnabled
    public Id memberId;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String membershipTier;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Date expiryDate;
    @AuraEnabled
    public Boolean canViewMedicalNotes;
    @AuraEnabled
    public String medicalNotes;
  }

  @AuraEnabled(cacheable=true)
  public static ProfileView getProfile(Id memberId) {
    if (memberId == null) {
      return null;
    }

    Boolean canViewNotes = Member__c.Medical_Notes__c.getDescribe()
      .isAccessible();

    String soql =
      'SELECT Id, Name, First_Name__c, Last_Name__c, Membership_Tier__c,' +
      ' Status__c, Expiry_Date__c';
    if (canViewNotes) {
      soql += ', Medical_Notes__c';
    }
    soql += ' FROM Member__c WHERE Id = :memberId WITH USER_MODE LIMIT 1';

    List<Member__c> members = Database.query(soql);
    if (members.isEmpty()) {
      return null;
    }

    Member__c m = members[0];
    ProfileView view = new ProfileView();
    view.memberId = m.Id;
    view.name = displayName(m);
    view.membershipTier = m.Membership_Tier__c;
    view.status = m.Status__c;
    view.expiryDate = m.Expiry_Date__c;
    view.canViewMedicalNotes = canViewNotes;
    if (canViewNotes) {
      view.medicalNotes = m.Medical_Notes__c;
    }
    return view;
  }

  private static String displayName(Member__c m) {
    String first = m.First_Name__c == null ? '' : m.First_Name__c.trim();
    String last = m.Last_Name__c == null ? '' : m.Last_Name__c.trim();
    String combined = (first + ' ' + last).trim();
    if (String.isNotBlank(combined)) {
      return combined;
    }
    return m.Name;
  }
}
