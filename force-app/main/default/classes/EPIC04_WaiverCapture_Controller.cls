/**
 * EPIC04-US-F005: front-desk digital waiver capture for Member__c or Lead__c.
 * Why Apex: creates Waiver_Record__c, updates Member waiver fields, and stores
 * the signature PNG as a ContentVersion in one transaction.
 */
public with sharing class EPIC04_WaiverCapture_Controller {
  public static final String MSG_OK = 'Waiver captured. Status is Signed.';
  public static final String MSG_NO_RECORD = 'Open a Member or Lead record to capture a waiver.';
  public static final String MSG_NO_TEMPLATE = 'No waiver template found. Ask an admin to create one.';
  public static final String MSG_NO_LOCATION = 'This record needs a Franchise Location before a waiver can be captured.';
  public static final String MSG_NO_SIGNATURE = 'Ask the visitor to sign on the pad before saving.';
  public static final String MSG_NO_SIGNER = 'Signer name and email are required.';
  public static final Integer DEFAULT_EXPIRY_DAYS = 365;

  public class CaptureContext {
    @AuraEnabled
    public String recordType;
    @AuraEnabled
    public String displayName;
    @AuraEnabled
    public String signerName;
    @AuraEnabled
    public String signerEmail;
    @AuraEnabled
    public Id locationId;
    @AuraEnabled
    public String locationName;
    @AuraEnabled
    public Id defaultTemplateId;
    @AuraEnabled
    public List<TemplateOption> templates;
  }

  public class TemplateOption {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String templateType;

    public TemplateOption(Id id, String name, String templateType) {
      this.id = id;
      this.name = name;
      this.templateType = templateType;
    }
  }

  public class CaptureResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public Id waiverId;
  }

  private class CaptureException extends Exception {
  }

  @AuraEnabled(cacheable=true)
  public static CaptureContext getCaptureContext(Id recordId) {
    try {
      return buildContext(recordId);
    } catch (CaptureException e) {
      AuraHandledException ahe = new AuraHandledException(e.getMessage());
      ahe.setMessage(e.getMessage());
      throw ahe;
    }
  }

  @AuraEnabled
  public static CaptureResult captureWaiver(
    Id recordId,
    String signerName,
    String signerEmail,
    String signerRole,
    Id templateId,
    String signaturePngBase64
  ) {
    CaptureResult result = new CaptureResult();
    Savepoint sp = Database.setSavepoint();
    try {
      if (recordId == null) {
        throw new CaptureException(MSG_NO_RECORD);
      }
      if (String.isBlank(signerName) || String.isBlank(signerEmail)) {
        throw new CaptureException(MSG_NO_SIGNER);
      }
      if (String.isBlank(signaturePngBase64)) {
        throw new CaptureException(MSG_NO_SIGNATURE);
      }

      CaptureContext ctx = buildContext(recordId);
      Id useTemplateId = templateId != null
        ? templateId
        : ctx.defaultTemplateId;
      if (useTemplateId == null) {
        throw new CaptureException(MSG_NO_TEMPLATE);
      }

      String role = String.isBlank(signerRole) ? 'Participant' : signerRole;
      Date expires = Date.today().addDays(DEFAULT_EXPIRY_DAYS);

      Waiver_Record__c waiver = new Waiver_Record__c(
        Name = 'WR-' + ctx.displayName.left(70),
        Franchise_Location__c = ctx.locationId,
        Waiver_Template__c = useTemplateId,
        Status__c = 'Signed',
        Effective_Date__c = Date.today(),
        Expiration_Date__c = expires,
        Signature_Timestamp__c = DateTime.now(),
        Signature_Method__c = 'Digital In-Person',
        Signer_Name__c = signerName.trim(),
        Signer_Email__c = signerEmail.trim(),
        Signer_Role__c = role,
        Signed_By__c = UserInfo.getUserId(),
        Is_Minor__c = role == 'Parent/Guardian'
      );

      if (ctx.recordType == 'Member') {
        waiver.Member__c = recordId;
      } else {
        waiver.Lead__c = recordId;
      }
      insert waiver;

      storeSignature(waiver.Id, signaturePngBase64, ctx.displayName);

      if (ctx.recordType == 'Member') {
        update new Member__c(
          Id = recordId,
          Waiver_Needed__c = false,
          Waiver_Signed__c = waiver.Id
        );
      }

      result.success = true;
      result.message = MSG_OK;
      result.waiverId = waiver.Id;
    } catch (CaptureException e) {
      Database.rollback(sp);
      result.success = false;
      result.message = e.getMessage();
    } catch (Exception e) {
      Database.rollback(sp);
      result.success = false;
      result.message = e.getMessage();
    }
    return result;
  }

  private static CaptureContext buildContext(Id recordId) {
    if (recordId == null) {
      throw new CaptureException(MSG_NO_RECORD);
    }

    CaptureContext ctx = new CaptureContext();
    ctx.templates = loadTemplates();
    if (ctx.templates.isEmpty()) {
      throw new CaptureException(MSG_NO_TEMPLATE);
    }
    ctx.defaultTemplateId = pickDefaultTemplateId(ctx.templates);

    String prefix = String.valueOf(recordId).left(3);
    if (prefix == Member__c.SObjectType.getDescribe().getKeyPrefix()) {
      Member__c m = [
        SELECT
          Id,
          Name,
          First_Name__c,
          Last_Name__c,
          Email__c,
          Home_Location__c,
          Home_Location__r.Name
        FROM Member__c
        WHERE Id = :recordId
        LIMIT 1
      ];
      ctx.recordType = 'Member';
      ctx.displayName = displayName(m.First_Name__c, m.Last_Name__c, m.Name);
      ctx.signerName = displayName(m.First_Name__c, m.Last_Name__c, m.Name);
      ctx.signerEmail = m.Email__c;
      ctx.locationId = m.Home_Location__c;
      ctx.locationName = m.Home_Location__r != null
        ? m.Home_Location__r.Name
        : null;
    } else if (prefix == Lead__c.SObjectType.getDescribe().getKeyPrefix()) {
      Lead__c lead = [
        SELECT
          Id,
          Name,
          First_Name__c,
          Last_Name__c,
          Email__c,
          Franchise_Location__c,
          Franchise_Location__r.Name
        FROM Lead__c
        WHERE Id = :recordId
        LIMIT 1
      ];
      ctx.recordType = 'Lead';
      ctx.displayName = displayName(
        lead.First_Name__c,
        lead.Last_Name__c,
        lead.Name
      );
      ctx.signerName = displayName(
        lead.First_Name__c,
        lead.Last_Name__c,
        lead.Name
      );
      ctx.signerEmail = lead.Email__c;
      ctx.locationId = lead.Franchise_Location__c;
      ctx.locationName = lead.Franchise_Location__r != null
        ? lead.Franchise_Location__r.Name
        : null;
    } else {
      throw new CaptureException(MSG_NO_RECORD);
    }

    if (ctx.locationId == null) {
      throw new CaptureException(MSG_NO_LOCATION);
    }
    return ctx;
  }

  private static List<TemplateOption> loadTemplates() {
    List<TemplateOption> options = new List<TemplateOption>();
    for (Waiver_Template__c t : [
      SELECT Id, Name, Template_Type__c, Is_Current__c
      FROM Waiver_Template__c
      ORDER BY Is_Current__c DESC, Name ASC
    ]) {
      options.add(new TemplateOption(t.Id, t.Name, t.Template_Type__c));
    }
    return options;
  }

  private static Id pickDefaultTemplateId(List<TemplateOption> templates) {
    for (TemplateOption t : templates) {
      if (t.templateType == 'Adult') {
        return t.id;
      }
    }
    return templates.isEmpty() ? null : templates[0].id;
  }

  private static String displayName(
    String first,
    String last,
    String fallback
  ) {
    String combined = ((first == null ? '' : first.trim()) +
      ' ' +
      (last == null ? '' : last.trim()))
      .trim();
    return String.isBlank(combined) ? fallback : combined;
  }

  private static void storeSignature(
    Id waiverId,
    String signaturePngBase64,
    String displayName
  ) {
    String raw = signaturePngBase64;
    if (raw.contains(',')) {
      raw = raw.substringAfter(',');
    }
    ContentVersion cv = new ContentVersion(
      Title = 'Waiver Signature - ' + displayName.left(60),
      PathOnClient = 'waiver-signature.png',
      VersionData = EncodingUtil.base64Decode(raw),
      FirstPublishLocationId = waiverId
    );
    insert cv;
  }
}
