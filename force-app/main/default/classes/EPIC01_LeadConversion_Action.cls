/**
 * EPIC01-US-002: invocable wrapper so the "Convert Lead to Member" screen flow
 * can call EPIC01_MemberOnboarding_Service and show its messages instead of
 * a raw Apex error. Why Apex: conversion touches several objects, tasks and
 * email in one transaction, with guards that are clearer and testable in code.
 */
public with sharing class EPIC01_LeadConversion_Action {

    public class Request {
        @InvocableVariable(required=true) public Id leadId;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
        @InvocableVariable public Id memberId;
    }

    @InvocableMethod(label='Convert Lead to Member' description='EPIC01-US-002')
    public static List<Result> convert(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            Savepoint sp = Database.setSavepoint();
            try {
                Member__c m = EPIC01_MemberOnboarding_Service.convertLeadToMember(req.leadId);
                r.success = true;
                r.memberId = m.Id;
                r.message = 'Lead converted to Member ' + m.Name;
            } catch (Exception e) {
                Database.rollback(sp);
                r.success = false;
                r.message = e.getMessage();
            }
            results.add(r);
        }
        return results;
    }
}
