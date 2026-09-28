@isTest
private class EPIC04_LeadRegistration_Test {

    @testSetup
    static void setupData() {
        // No specific setup data needed for this simple lead creation test
    }

    @isTest
    static void testSuccessfulLeadRegistration() {
        // Test a successful lead registration
        Test.startTest();
        Id leadId = EPIC04_LeadRegistration_Controller.createLead(
            'John',
            'Smith',
            '555-123-4567',
            'john@example.com'
        );
        Test.stopTest();

        // Verify lead was created with correct data
        System.assertNotEquals(null, leadId, 'Lead Id should not be null');
        Lead__c createdLead = [SELECT Id, First_Name__c, Last_Name__c, Phone__c, Email__c, Status__c, Lead_Source__c FROM Lead__c WHERE Id = :leadId];

        System.assertEquals('John', createdLead.First_Name__c, 'First Name should match');
        System.assertEquals('Smith', createdLead.Last_Name__c, 'Last Name should match');
        System.assertEquals('555-123-4567', createdLead.Phone__c, 'Phone should match');
        System.assertEquals('john@example.com', createdLead.Email__c, 'Email should match');
        System.assertEquals('Walk-In', createdLead.Status__c, 'Lead Status should be Walk-In');
        System.assertEquals('In Person', createdLead.Lead_Source__c, 'Lead Source should be In Person');
    }
}