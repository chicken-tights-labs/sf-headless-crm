@isTest
private class EPIC04_ManagerPin_Test {
  @isTest
  static void staffCannotSetAPin() {
    try {
      EPIC04_ManagerPin_Service.setMyPin('1234');
      System.assert(false, 'expected manager-only error');
    } catch (AuraHandledException ex) {
      System.assertEquals(
        EPIC04_ManagerPin_Service.MSG_MANAGER_ONLY,
        ex.getMessage()
      );
    }
    System.assertEquals(false, EPIC04_ManagerPin_Service.canManagePins());
  }

  @isTest
  static void managerPinApprovesAndDoesNotStoreTheDigits() {
    assignManagerPermission();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      EPIC04_ManagerPin_Service.setMyPin('4321');
      System.assertEquals(
        UserInfo.getUserId(),
        EPIC04_ManagerPin_Service.findApprover('4321')
      );
      System.assertEquals(null, EPIC04_ManagerPin_Service.findApprover('9999'));
      System.assertEquals(null, EPIC04_ManagerPin_Service.findApprover('12'));
    }
    Manager_Pin__c stored = [
      SELECT Pin_Hash__c
      FROM Manager_Pin__c
      WHERE User_Id__c = :String.valueOf(UserInfo.getUserId())
    ];
    System.assertNotEquals('4321', stored.Pin_Hash__c);
    System.assertEquals(64, stored.Pin_Hash__c.length());
  }

  @isTest
  static void replacingAPinRetiresTheOldOne() {
    assignManagerPermission();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      EPIC04_ManagerPin_Service.setMyPin('1111');
      EPIC04_ManagerPin_Service.setMyPin('2222');
      System.assertEquals(null, EPIC04_ManagerPin_Service.findApprover('1111'));
      System.assertEquals(
        UserInfo.getUserId(),
        EPIC04_ManagerPin_Service.findApprover('2222')
      );
    }
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Manager_Pin__c
        WHERE User_Id__c = :String.valueOf(UserInfo.getUserId())
      ]
    );
  }

  private static void assignManagerPermission() {
    PermissionSet ps = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Boxing_Gym_Manager'
      LIMIT 1
    ];
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert new PermissionSetAssignment(
        AssigneeId = UserInfo.getUserId(),
        PermissionSetId = ps.Id
      );
    }
  }
}
