/**
 * EPIC01-US-001: REST endpoint for lead capture.
 *
 * POST /services/apexrest/leadcapture
 * Body: JSON matching EPIC01_LeadCapture_Service.Request
 * Used by the NBS Gym web form, the trainer app and the Facebook Lead Ad webhook relay.
 * Why Apex: Flow cannot expose an inbound REST endpoint.
 */
@RestResource(urlMapping='/leadcapture/*')
global with sharing class EPIC01_LeadCapture_Rest {

    @HttpPost
    global static void doPost() {
        RestResponse out = RestContext.response;
        out.addHeader('Content-Type', 'application/json');
        EPIC01_LeadCapture_Service.Response res;
        try {
            EPIC01_LeadCapture_Service.Request req = (EPIC01_LeadCapture_Service.Request)
                JSON.deserialize(RestContext.request.requestBody.toString(),
                                 EPIC01_LeadCapture_Service.Request.class);
            res = EPIC01_LeadCapture_Service.capture(req);
        } catch (Exception e) {
            res = new EPIC01_LeadCapture_Service.Response();
            res.success = false;
            res.message = 'Invalid request body';
            res.errors.add(res.message);
        }
        out.statusCode = res.success ? 201 : (res.duplicate ? 409 : 400);
        out.responseBody = Blob.valueOf(JSON.serialize(res));
    }
}
