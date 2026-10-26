/**
 * EPIC04-US-F007: store and check a manager merchandise PIN.
 * Why Apex: the hash has to be compared without giving the front desk access to the record.
 * without sharing so the sale can check another user's PIN while the object stays private.
 */
public without sharing class EPIC04_ManagerPin_Service {
  public static final String PERMISSION = 'Manage_Merchandise_Discount';
  public static final String MSG_MANAGER_ONLY = 'Only a manager can set a merchandise PIN.';
  public static final String MSG_PIN_FORMAT = 'Enter a 4 to 6 digit PIN.';

  @AuraEnabled
  public static Boolean canManagePins() {
    return FeatureManagement.checkPermission(PERMISSION);
  }

  @AuraEnabled
  public static void setMyPin(String pin) {
    if (!canManagePins()) {
      throw auraError(MSG_MANAGER_ONLY);
    }
    if (String.isBlank(pin) || !Pattern.matches('\\d{4,6}', pin)) {
      throw auraError(MSG_PIN_FORMAT);
    }
    String hash = hashPin(UserInfo.getUserId(), pin);
    List<Manager_Pin__c> existing = [
      SELECT Id
      FROM Manager_Pin__c
      WHERE User__c = :UserInfo.getUserId()
      LIMIT 1
    ];
    if (existing.isEmpty()) {
      insert new Manager_Pin__c(
        User__c = UserInfo.getUserId(),
        Pin_Hash__c = hash
      );
    } else {
      existing[0].Pin_Hash__c = hash;
      update existing[0];
    }
  }

  public static Id findApprover(String pin) {
    if (String.isBlank(pin) || !Pattern.matches('\\d{4,6}', pin)) {
      return null;
    }
    for (Manager_Pin__c row : [
      SELECT User__c, Pin_Hash__c
      FROM Manager_Pin__c
    ]) {
      if (row.Pin_Hash__c == hashPin(row.User__c, pin)) {
        return row.User__c;
      }
    }
    return null;
  }

  @TestVisible
  private static String hashPin(Id userId, String pin) {
    Blob digest = Crypto.generateDigest(
      'SHA-256',
      Blob.valueOf(String.valueOf(userId) + ':' + pin)
    );
    return EncodingUtil.convertToHex(digest);
  }

  private static AuraHandledException auraError(String message) {
    AuraHandledException ex = new AuraHandledException(message);
    ex.setMessage(message);
    return ex;
  }
}
