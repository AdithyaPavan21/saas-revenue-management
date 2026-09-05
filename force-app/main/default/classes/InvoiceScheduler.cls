public with sharing class InvoiceScheduler implements Schedulable {

    public void execute(SchedulableContext context){
        Database.executeBatch(new InvoiceBatch(), 200);
    }
}