@isTest
private class EPIC04_LeadRegistration_Test {

    @testSetup
    static void setupData() {
        // Create a Franchise_Location__c record (required lookup on Lead__c)
        Franchise_Location__c location = new Franchise_Location__c(
            Name = 'NBS Gym - Lexington'
        );
        insert location;
    }

    @isTest
    static void testSuccessfulLeadRegistration() {
        // Test a successful lead registration
        // Get the Franchise_Location__c created in testSetup
        Franchise_Location__c location = [SELECT Id FROM Franchise_Location__c LIMIT 1];

        Test.startTest();
        Id leadId = EPIC04_LeadRegistration_Controller.createLead(
            'John',
            'Smith',
            '555-123-4567',
            'john@example.com',
            location.Id
        );
        Test.stopTest();

        // Verify lead was created with correct data
        System.assertNotEquals(null, leadId, 'Lead Id should not be null');
        Lead__c createdLead = [SELECT Id, First_Name__c, Last_Name__c, Phone__c, Email__c, Lead_Status__c, Lead_Source__c FROM Lead__c WHERE Id = :leadId];

        System.assertEquals('John', createdLead.First_Name__c, 'First Name should match');
        System.assertEquals('Smith', createdLead.Last_Name__c, 'Last Name should match');
        System.assertEquals('555-123-4567', createdLead.Phone__c, 'Phone should match');
        System.assertEquals('john@example.com', createdLead.Email__c, 'Email should match');
        System.assertEquals('Walk-In', createdLead.Lead_Status__c, 'Lead Status should be Walk-In');
        System.assertEquals('In Person', createdLead.Lead_Source__c, 'Lead Source should be In Person');
    }
}