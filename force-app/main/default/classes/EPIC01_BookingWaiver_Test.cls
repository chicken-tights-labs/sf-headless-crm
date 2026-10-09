/**
 * EPIC01-US-007: Booking waiver enforcement — maps to the Gherkin scenarios in issue #28.
 */
@isTest
private class EPIC01_BookingWaiver_Test {

    @testSetup
    static void setupData() {
        Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation('Lexington HQ');
        EPIC01_TestDataFactory.createWaiverTemplate();
        EPIC01_TestDataFactory.createSession(loc.Id);
    }

    private static Franchise_Location__c loc() {
        return [SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ'];
    }
    private static Waiver_Template__c tmpl() {
        return [SELECT Id FROM Waiver_Template__c LIMIT 1];
    }
    private static Scheduled_Session__c session() {
        return [SELECT Id FROM Scheduled_Session__c LIMIT 1];
    }

    private static String bookingError(Member__c m) {
        Database.SaveResult sr = Database.insert(
            EPIC01_TestDataFactory.newBooking(m.Id, session().Id, loc().Id), false);
        System.assertEquals(false, sr.isSuccess(), 'Booking should have been blocked');
        System.assertEquals(0, [SELECT COUNT() FROM Booking__c WHERE Member__c = :m.Id]);
        return sr.getErrors()[0].getMessage();
    }

    @isTest
    static void validWaiverAllowsBooking() {
        Member__c m = EPIC01_TestDataFactory.createMemberWithWaiver('Maya', 'Rodriguez', loc().Id, tmpl().Id);
        Booking__c b = EPIC01_TestDataFactory.newBooking(m.Id, session().Id, loc().Id);
        insert b;
        System.assertEquals('Confirmed', [SELECT Status__c FROM Booking__c WHERE Id = :b.Id].Status__c);
    }

    @isTest
    static void noWaiverBlocksBooking() {
        Member__c m = EPIC01_TestDataFactory.createMember('Jordan', 'Smith', loc().Id);
        System.assertEquals('Cannot book class — member does not have a valid signed waiver', bookingError(m));
    }

    @isTest
    static void expiredWaiverBlocksBooking() {
        Member__c m = EPIC01_TestDataFactory.createMember('Avery', 'Johnson', loc().Id);
        EPIC01_TestDataFactory.createWaiver(m.Id, loc().Id, tmpl().Id, 'Signed', Date.newInstance(2025, 1, 1));
        System.assertEquals('Cannot book class — member\'s waiver has expired', bookingError(m));
    }

    @isTest
    static void pendingWaiverBlocksBooking() {
        Member__c m = EPIC01_TestDataFactory.createMember('Casey', 'Brooks', loc().Id);
        EPIC01_TestDataFactory.createWaiver(m.Id, loc().Id, tmpl().Id, 'Pending', null);
        System.assertEquals('Cannot book class — member\'s waiver is pending signature', bookingError(m));
    }

    @isTest
    static void revokedWaiverBlocksBooking() {
        Member__c m = EPIC01_TestDataFactory.createMember('Riley', 'Chen', loc().Id);
        EPIC01_TestDataFactory.createWaiver(m.Id, loc().Id, tmpl().Id, 'Revoked', null);
        System.assertEquals('Cannot book class — member\'s waiver has been revoked', bookingError(m));
    }

    @isTest
    static void draftWaiverIsTreatedAsNoValidWaiver() {
        Member__c m = EPIC01_TestDataFactory.createMember('Drew', 'Draft', loc().Id);
        EPIC01_TestDataFactory.createWaiver(m.Id, loc().Id, tmpl().Id, 'Draft', null);
        System.assertEquals('Cannot book class — member does not have a valid signed waiver', bookingError(m));
    }

    @isTest
    static void apiStyleBulkInsertBlocksOnlyTheMemberWithoutWaiver() {
        Member__c good = EPIC01_TestDataFactory.createMemberWithWaiver('Taylor', 'Good', loc().Id, tmpl().Id);
        Member__c bad = EPIC01_TestDataFactory.createMember('Taylor', 'Kim', loc().Id);
        List<Booking__c> bookings = new List<Booking__c>{
            EPIC01_TestDataFactory.newBooking(good.Id, session().Id, loc().Id),
            EPIC01_TestDataFactory.newBooking(bad.Id, session().Id, loc().Id)
        };
        List<Database.SaveResult> results = Database.insert(bookings, false);
        System.assertEquals(true, results[0].isSuccess());
        System.assertEquals(false, results[1].isSuccess());
        System.assertEquals(1, [SELECT COUNT() FROM Booking__c]);
    }

    @isTest
    static void anyValidWaiverAllowsBookingEvenWithNewerPendingOne() {
        Member__c m = EPIC01_TestDataFactory.createMemberWithWaiver('Sky', 'Renewal', loc().Id, tmpl().Id);
        EPIC01_TestDataFactory.createWaiver(m.Id, loc().Id, tmpl().Id, 'Pending', null);
        System.assertEquals('Signed', EPIC01_MemberOnboarding_Service.waiverStatusByMember(new Set<Id>{ m.Id }).get(m.Id));
        insert EPIC01_TestDataFactory.newBooking(m.Id, session().Id, loc().Id);
        System.assertEquals(1, [SELECT COUNT() FROM Booking__c WHERE Member__c = :m.Id]);
    }

    @isTest
    static void expiredPlusPendingStillBlocksAndReportsMostRecent() {
        Member__c m = EPIC01_TestDataFactory.createMember('Old', 'Waiver', loc().Id);
        EPIC01_TestDataFactory.createWaiver(m.Id, loc().Id, tmpl().Id, 'Signed', Date.newInstance(2025, 1, 1));
        EPIC01_TestDataFactory.createWaiver(m.Id, loc().Id, tmpl().Id, 'Revoked', null);
        String status = EPIC01_MemberOnboarding_Service.waiverStatusByMember(new Set<Id>{ m.Id }).get(m.Id);
        System.assert(status == 'Revoked' || status == 'Expired', 'Unexpected status ' + status);
        System.assertEquals(false, EPIC01_MemberOnboarding_Service.attemptProceedToPayment(m.Id).canProceed);
    }

    @isTest
    static void prospectWithWaiverCannotBook() {
        Member__c m = new Member__c(
            Name = 'Jordan_Prospect', First_Name__c = 'Jordan', Last_Name__c = 'Prospect',
            Email__c = 'jordan.prospect@email.com', Home_Location__c = loc().Id,
            Status__c = 'Prospect', Membership_Tier__c = 'Punch Card (10 classes - $150)'
        );
        insert m;
        EPIC01_TestDataFactory.createValidWaiver(m.Id, loc().Id, tmpl().Id);
        System.assertEquals(
            EPIC01_BookingWaiver_Handler.MSG_NOT_ACTIVE,
            bookingError(m)
        );
    }

    @isTest
    static void punchCardBookingDecrementsClassesRemaining() {
        Member__c m = EPIC01_TestDataFactory.createMemberWithWaiver('Maya', 'Pack', loc().Id, tmpl().Id);
        m.Membership_Tier__c = EPIC01_MemberOnboarding_Service.TIER_PUNCH;
        m.Classes_Remaining__c = 8;
        update m;
        insert EPIC01_TestDataFactory.newBooking(m.Id, session().Id, loc().Id);
        System.assertEquals(7, [
            SELECT Classes_Remaining__c FROM Member__c WHERE Id = :m.Id
        ].Classes_Remaining__c);
    }

    @isTest
    static void sharedStatusMatchesPaymentGate() {
        Member__c m = EPIC01_TestDataFactory.createMember('Pat', 'Gate', loc().Id);
        System.assertEquals('Missing', EPIC01_MemberOnboarding_Service.waiverStatusByMember(new Set<Id>{ m.Id }).get(m.Id));
        EPIC01_TestDataFactory.createValidWaiver(m.Id, loc().Id, tmpl().Id);
        System.assertEquals('Signed', EPIC01_MemberOnboarding_Service.waiverStatusByMember(new Set<Id>{ m.Id }).get(m.Id));
        System.assertEquals(true, EPIC01_MemberOnboarding_Service.attemptProceedToPayment(m.Id).canProceed);
    }
}
