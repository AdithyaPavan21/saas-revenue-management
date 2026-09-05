public with sharing class InvoiceService {

    public static void generateInvoices(List<Subscription__c> subscriptions) {

        if (subscriptions == null || subscriptions.isEmpty()) {
            return;
        }

        Date today = Date.today();
        Billing_Setting__mdt billingSetting = Billing_Setting__mdt.getInstance('Default');
       Decimal taxRate = 0;
    if (billingSetting != null && billingSetting.Tax_Rate__c != null) {
    taxRate = billingSetting.Tax_Rate__c / 100;
}

        Map<Id, Subscription__c> eligibleSubscriptions =
            new Map<Id, Subscription__c>();

        Map<Id, String> subscriptionToBillingKey =
            new Map<Id, String>();

        Set<String> billingKeys = new Set<String>();

        for (Subscription__c sub : subscriptions) {

            if (
                sub.Status__c != 'Active' ||
                sub.Next_Billing_Date__c == null ||
                sub.Next_Billing_Date__c > today
            ) {
                continue;
            }

            String billingKey =
                sub.Id + '-' +
                String.valueOf(
                    sub.Next_Billing_Date__c.year()
                ).right(2) +
                String.valueOf(
                    sub.Next_Billing_Date__c.month()
                ).leftPad(2, '0');

            eligibleSubscriptions.put(sub.Id, sub);
            subscriptionToBillingKey.put(sub.Id, billingKey);
            billingKeys.add(billingKey);
        }

        if (eligibleSubscriptions.isEmpty()) {
            return;
        }

        Set<String> existingBillingKeys = new Set<String>();

        for (Invoice__c existingInvoice : [
            SELECT Billing_Cycle_Key__c
            FROM Invoice__c
            WHERE Billing_Cycle_Key__c IN :billingKeys
        ]) {
            existingBillingKeys.add(
                existingInvoice.Billing_Cycle_Key__c
            );
        }

        List<Invoice__c> invoicesToInsert =
            new List<Invoice__c>();

        List<Subscription__c> subscriptionsToUpdate =
            new List<Subscription__c>();

        for (Subscription__c sub : eligibleSubscriptions.values()) {

            String billingKey =
                subscriptionToBillingKey.get(sub.Id);

            if (existingBillingKeys.contains(billingKey)) {
                continue;
            }

            Decimal billingMultiplier = 1;
            Date billingPeriodEnd;
            Date nextBillingDate;

            if (sub.Billing_Frequency__c == 'Monthly') {

                billingMultiplier = 1;

                billingPeriodEnd =
                    sub.Next_Billing_Date__c
                        .addMonths(1)
                        .addDays(-1);

                nextBillingDate =
                    sub.Next_Billing_Date__c
                        .addMonths(1);

            } else if (
                sub.Billing_Frequency__c == 'Quarterly'
            ) {

                billingMultiplier = 3;

                billingPeriodEnd =
                    sub.Next_Billing_Date__c
                        .addMonths(3)
                        .addDays(-1);

                nextBillingDate =
                    sub.Next_Billing_Date__c
                        .addMonths(3);

            } else if (
                sub.Billing_Frequency__c == 'Annual'
            ) {

                billingMultiplier = 12;

                billingPeriodEnd =
                    sub.Next_Billing_Date__c
                        .addMonths(12)
                        .addDays(-1);

                nextBillingDate =
                    sub.Next_Billing_Date__c
                        .addMonths(12);

            } else {

                continue;
            }

            Decimal invoiceAmount =
                sub.Subscription_Amount__c *
                billingMultiplier;

            Decimal taxAmount =
                invoiceAmount * taxRate;

            Invoice__c invoice = new Invoice__c(

                Subscription__c = sub.Id,

                Account__c = sub.Account__c,

                Invoice_Date__c =
                    sub.Next_Billing_Date__c,

                Due_Date__c =
                    sub.Next_Billing_Date__c
                        .addDays(7),

                Billing_Period_Start__c =
                    sub.Next_Billing_Date__c,

                Billing_Period_End__c =
                    billingPeriodEnd,

                Amount__c =
                    invoiceAmount,

                Tax__c =
                    taxAmount,

                Status__c =
                    'Pending',

                Billing_Cycle_Key__c =
                    billingKey
            );

            invoicesToInsert.add(invoice);

            sub.Next_Billing_Date__c =
                nextBillingDate;

            subscriptionsToUpdate.add(sub);
        }
        if (!invoicesToInsert.isEmpty()) {
            insert invoicesToInsert;
        }

        if (!subscriptionsToUpdate.isEmpty()) {
            update subscriptionsToUpdate;
        }
    }
}