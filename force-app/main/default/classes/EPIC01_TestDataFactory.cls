/**
 * Shared Apex test data helpers for EPIC01 tests.
 * Any test that inserts a Booking__c needs a member with a valid signed waiver
 * (see EPIC01_BookingWaiverGuard). Use createMemberWithWaiver for that.
 * This class only exists in tests; there is no bypass of the waiver rule in production code.
 */
@isTest
public class EPIC01_TestDataFactory {

    public static Franchise_Location__c createLocation(String name) {
        Franchise_Owner__c owner = new Franchise_Owner__c(
            Name = 'Test Owner ' + name, Contact_First_Name__c = 'Jane', Contact_Last_Name__c = 'Smith',
            Legal_Name__c = 'Test Owner Legal ' + name, Email__c = 'owner@test.com'
        );
        insert owner;
        Franchise_Location__c loc = new Franchise_Location__c(
            Name = name, Status__c = 'Active', Franchise_Owner__c = owner.Id
        );
        insert loc;
        return loc;
    }

    public static Waiver_Template__c createWaiverTemplate() {
        Waiver_Template__c tmpl = new Waiver_Template__c(
            Name = 'General Liability Waiver - Fencing & Boxing', Template_Type__c = 'Adult',
            Content_Version_Id__c = '068000000000001', Effective_Date__c = Date.today()
        );
        insert tmpl;
        return tmpl;
    }

    public static Member__c createMember(String first, String last, Id locationId) {
        Member__c m = new Member__c(
            Name = first + '_' + last, First_Name__c = first, Last_Name__c = last,
            Email__c = first.toLowerCase() + '.' + last.toLowerCase() + '@email.com',
            Home_Location__c = locationId, Status__c = 'Active'
        );
        insert m;
        return m;
    }

    public static Waiver_Record__c createWaiver(Id memberId, Id locationId, Id templateId,
                                               String status, Date expiration) {
        Waiver_Record__c w = new Waiver_Record__c(
            Name = 'WR-' + memberId, Franchise_Location__c = locationId, Member__c = memberId,
            Waiver_Template__c = templateId, Status__c = status, Expiration_Date__c = expiration,
            Signature_Timestamp__c = DateTime.now(), Signature_Method__c = 'Digital In-Person',
            Signer_Email__c = 'signer@email.com', Signer_Role__c = 'Participant'
        );
        insert w;
        return w;
    }

    /** A valid, signed, non-expired waiver (expires in one year). */
    public static Waiver_Record__c createValidWaiver(Id memberId, Id locationId, Id templateId) {
        return createWaiver(memberId, locationId, templateId, 'Signed', Date.today().addDays(365));
    }

    /** Convenience: Active member plus a valid signed waiver, ready to book. */
    public static Member__c createMemberWithWaiver(String first, String last, Id locationId, Id templateId) {
        Member__c m = createMember(first, last, locationId);
        createValidWaiver(m.Id, locationId, templateId);
        return m;
    }

    public static Scheduled_Session__c createSession(Id locationId) {
        Scheduled_Session__c s = new Scheduled_Session__c(
            Name = 'Boxing Fundamentals - 60min', Franchise_Location__c = locationId,
            Max_Capacity__c = 20, Program_Type__c = 'Boxing Fundamentals', Session_Status__c = 'Scheduled'
        );
        insert s;
        return s;
    }

    public static Booking__c newBooking(Id memberId, Id sessionId, Id locationId) {
        return new Booking__c(
            Name = 'Booking ' + memberId, Member__c = memberId, Scheduled_Session__c = sessionId,
            Franchise_Location__c = locationId, Status__c = 'Confirmed', Booking_Date__c = DateTime.now()
        );
    }
}
