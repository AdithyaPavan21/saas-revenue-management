public with sharing class PaymentService {
@AuraEnabled
    public static Payment__c processPayment(
        Id invoiceId,
        Decimal paymentAmount,
        String paymentMethod,
        String transactionId
    ) {

        if (invoiceId == null) {
            throw new AuraHandledException('Invoice Id is required.');
        }

        if (paymentAmount == null || paymentAmount <= 0) {
            throw new AuraHandledException(
                'Payment amount must be greater than zero.'
            );
        }

        if (String.isBlank(transactionId)) {
            throw new AuraHandledException(
                'Transaction Id is required.'
            );
        }

        Invoice__c invoice = [
            SELECT Id,
                   Account__c,
                   Status__c,
                   Total_Amount__c,
                   Payment_Date__c
            FROM Invoice__c
            WHERE Id = :invoiceId
            LIMIT 1
        ];

        if (invoice.Status__c == 'Paid') {
            throw new AuraHandledException(
                'Invoice is already paid.'
            );
        }

        if (paymentAmount != invoice.Total_Amount__c) {
            throw new AuraHandledException(
                'Payment amount must match the invoice total amount.'
            );
        }

        List<Payment__c> existingPayments = [
            SELECT Id
            FROM Payment__c
            WHERE Transaction_ID__c = :transactionId
            LIMIT 1
        ];

        if (!existingPayments.isEmpty()) {
            throw new AuraHandledException(
                'Duplicate transaction detected.'
            );
        }

        Payment__c payment = new Payment__c(
            Invoice__c = invoice.Id,
            Account__c = invoice.Account__c,
            Amount__c = paymentAmount,
            Payment_Method__c = paymentMethod,
            Transaction_ID__c = transactionId,
            Payment_Date__c = System.now(),
            Status__c = 'Successful'
        );

        insert payment;

        invoice.Status__c = 'Paid';
        invoice.Payment_Date__c = Date.today();

        update invoice;

        return payment;
    }
}