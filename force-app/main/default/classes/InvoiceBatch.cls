public with sharing class InvoiceBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator([SELECT Id, Account__c, Status__c, Next_Billing_Date__c, Billing_Frequency__c, Subscription_Amount__c FROM Subscription__c WHERE Status__c = 'Active' AND Next_Billing_Date__c <= :Date.today()]);
    }

    public void execute(Database.BatchableContext bc, List<Subscription__c> scope){
        InvoiceService.generateInvoices(scope);
    }

    public void finish(Database.BatchableContext bc){
        
    }
}