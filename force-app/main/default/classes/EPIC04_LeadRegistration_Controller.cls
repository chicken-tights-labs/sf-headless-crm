public with sharing class EPIC04_LeadRegistration_Controller {

    @AuraEnabled
    public static Id createLead(String firstName, String lastName, String phone, String email) {
        Lead__c newLead = new Lead__c(
            First_Name__c = firstName,
            Last_Name__c  = lastName,
            Phone__c      = phone,
            Email__c      = email,
            Lead_Status__c = 'Walk-In',
            Lead_Source__c = 'In Person'
        );
        insert newLead;
        return newLead.Id;
    }
}