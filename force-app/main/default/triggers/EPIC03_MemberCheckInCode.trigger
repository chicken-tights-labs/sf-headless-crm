/**
 * EPIC03-US-T002: assign a check-in code when Member__c.Check_In_Code__c is blank.
 */
trigger EPIC03_MemberCheckInCode on Member__c(before insert, before update) {
  EPIC03_CheckInCode_Service.fillBlank(Trigger.new);
}
