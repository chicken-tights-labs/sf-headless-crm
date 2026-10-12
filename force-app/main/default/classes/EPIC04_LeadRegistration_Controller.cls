public with sharing class EPIC04_LeadRegistration_Controller {
  @AuraEnabled(cacheable=true)
  public static List<Franchise_Location__c> getActiveLocations() {
    return [
      SELECT Id, Name
      FROM Franchise_Location__c
      WHERE Status__c = 'Active'
      ORDER BY Name
    ];
  }

  @AuraEnabled
  public static Id createLead(
    String firstName,
    String lastName,
    String phone,
    String email,
    String franchiseLocationId
  ) {
    Lead__c newLead = new Lead__c(
      First_Name__c = firstName,
      Last_Name__c = lastName,
      Phone__c = phone,
      Email__c = email,
      Lead_Status__c = 'Walk-In',
      Lead_Source__c = 'In Person',
      Franchise_Location__c = franchiseLocationId
    );
    insert newLead;
    return newLead.Id;
  }
}
