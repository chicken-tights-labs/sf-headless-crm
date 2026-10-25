/**
 * EPIC03-US-T002: random member check-in codes.
 * Why Apex: a unique code has to be random, not a phone or email, and a
 * replacement has to overwrite the old value in one update.
 */
public with sharing class EPIC03_CheckInCode_Service {
  public static final String MSG_MEMBER_NOT_FOUND = 'Member not found.';

  /** Before save: fill a blank code. Leaves an existing code unchanged. */
  public static void fillBlank(List<Member__c> members) {
    if (members == null) {
      return;
    }
    Set<String> used = new Set<String>();
    for (Member__c member : members) {
      if (member == null || !String.isBlank(member.Check_In_Code__c)) {
        continue;
      }
      member.Check_In_Code__c = uniqueCode(used);
    }
  }

  @AuraEnabled(cacheable=true)
  public static String currentCode(Id memberId) {
    if (memberId == null) {
      return null;
    }
    List<Member__c> rows = [
      SELECT Check_In_Code__c
      FROM Member__c
      WHERE Id = :memberId
      LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0].Check_In_Code__c;
  }

  /**
   * Members saved before this trigger existed have a blank code.
   * Re-run until it returns 0. Each pass updates at most 200 rows.
   */
  public static Integer fillAllBlank() {
    List<Member__c> blank = [
      SELECT Id, Check_In_Code__c
      FROM Member__c
      WHERE Check_In_Code__c = NULL
      LIMIT 200
    ];
    if (blank.isEmpty()) {
      return 0;
    }
    update blank;
    return blank.size();
  }

  /** Overwrites Check_In_Code__c. The previous value stops matching. */
  @AuraEnabled
  public static String replaceCode(Id memberId) {
    if (memberId == null) {
      throw memberNotFound();
    }
    List<Member__c> rows = [
      SELECT Id
      FROM Member__c
      WHERE Id = :memberId
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      throw memberNotFound();
    }
    String next = newCode();
    rows[0].Check_In_Code__c = next;
    update rows[0];
    return next;
  }

  @TestVisible
  static String uniqueCode(Set<String> used) {
    String code = newCode();
    while (used.contains(code)) {
      code = newCode();
    }
    used.add(code);
    return code;
  }

  @TestVisible
  static String newCode() {
    return EncodingUtil.convertToHex(Crypto.generateAesKey(128)).toUpperCase();
  }

  private static AuraHandledException memberNotFound() {
    AuraHandledException ex = new AuraHandledException(MSG_MEMBER_NOT_FOUND);
    ex.setMessage(MSG_MEMBER_NOT_FOUND);
    return ex;
  }
}
