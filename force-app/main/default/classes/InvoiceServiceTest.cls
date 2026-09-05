@IsTest
private class InvoiceServiceTest {

    @TestSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Test SaaS Customer'
        );
        insert acc;

        List<Subscription__c> subscriptions = new List<Subscription__c>{
            new Subscription__c(
                Account__c = acc.Id,
                Status__c = 'Active',
                Billing_Frequency__c = 'Monthly',
                Subscription_Amount__c = 1999,
                Next_Billing_Date__c = Date.today()
            ),

            new Subscription__c(
                Account__c = acc.Id,
                Status__c = 'Active',
                Billing_Frequency__c = 'Quarterly',
                Subscription_Amount__c = 1999,
                Next_Billing_Date__c = Date.today()
            ),

            new Subscription__c(
                Account__c = acc.Id,
                Status__c = 'Active',
                Billing_Frequency__c = 'Annual',
                Subscription_Amount__c = 1999,
                Next_Billing_Date__c = Date.today()
            )
        };

        insert subscriptions;
    }

    @IsTest
    static void testInvoiceGeneration() {

        List<Subscription__c> subscriptions = [
            SELECT Id,
                   Account__c,
                   Status__c,
                   Billing_Frequency__c,
                   Subscription_Amount__c,
                   Next_Billing_Date__c
            FROM Subscription__c
        ];

        Test.startTest();

        InvoiceService.generateInvoices(subscriptions);

        Test.stopTest();

        List<Invoice__c> invoices = [
            SELECT Id,
                   Subscription__c,
                   Amount__c,
                   Tax__c,
                   Total_Amount__c,
                   Invoice_Date__c,
                   Due_Date__c,
                   Billing_Period_Start__c,
                   Billing_Period_End__c,
                   Billing_Cycle_Key__c,
                   Status__c
            FROM Invoice__c
        ];

        System.assertEquals(
            3,
            invoices.size(),
            'Three invoices should be generated'
        );

        Map<Id, Invoice__c> invoiceBySubscription =
            new Map<Id, Invoice__c>();

        for (Invoice__c inv : invoices) {
            invoiceBySubscription.put(
                inv.Subscription__c,
                inv
            );
        }

        for (Subscription__c sub : subscriptions) {

            Invoice__c inv =
                invoiceBySubscription.get(sub.Id);

            System.assertNotEquals(
                null,
                inv,
                'Invoice should exist'
            );

            System.assertEquals(
                'Pending',
                inv.Status__c
            );

            System.assertEquals(
                Date.today(),
                inv.Invoice_Date__c
            );

            System.assertEquals(
                Date.today().addDays(7),
                inv.Due_Date__c
            );

            if (sub.Billing_Frequency__c == 'Monthly') {

                System.assertEquals(
                    1999,
                    inv.Amount__c
                );

                System.assertEquals(
                    359.82,
                    inv.Tax__c
                );

                System.assertEquals(
                    Date.today()
                        .addMonths(1)
                        .addDays(-1),
                    inv.Billing_Period_End__c
                );

            } else if (
                sub.Billing_Frequency__c == 'Quarterly'
            ) {

                System.assertEquals(
                    5997,
                    inv.Amount__c
                );

                System.assertEquals(
                    1079.46,
                    inv.Tax__c
                );

                System.assertEquals(
                    Date.today()
                        .addMonths(3)
                        .addDays(-1),
                    inv.Billing_Period_End__c
                );

            } else if (
                sub.Billing_Frequency__c == 'Annual'
            ) {

                System.assertEquals(
                    23988,
                    inv.Amount__c
                );

                System.assertEquals(
                    4317.84,
                    inv.Tax__c
                );

                System.assertEquals(
                    Date.today()
                        .addMonths(12)
                        .addDays(-1),
                    inv.Billing_Period_End__c
                );
            }
        }
    }

    @IsTest
    static void testDeduplication() {

        Subscription__c sub = [
            SELECT Id,
                   Account__c,
                   Status__c,
                   Billing_Frequency__c,
                   Subscription_Amount__c,
                   Next_Billing_Date__c
            FROM Subscription__c
            WHERE Billing_Frequency__c = 'Monthly'
            LIMIT 1
        ];

        Date originalBillingDate =
            sub.Next_Billing_Date__c;

        Test.startTest();

        InvoiceService.generateInvoices(
            new List<Subscription__c>{sub}
        );

        Test.stopTest();

        Integer firstCount = [
            SELECT COUNT()
            FROM Invoice__c
            WHERE Subscription__c = :sub.Id
        ];

        System.assertEquals(1, firstCount);

        // Simulate same billing cycle being processed again
        sub.Next_Billing_Date__c =
            originalBillingDate;

        update sub;

        sub = [
            SELECT Id,
                   Account__c,
                   Status__c,
                   Billing_Frequency__c,
                   Subscription_Amount__c,
                   Next_Billing_Date__c
            FROM Subscription__c
            WHERE Id = :sub.Id
        ];

        InvoiceService.generateInvoices(
            new List<Subscription__c>{sub}
        );

        Integer secondCount = [
            SELECT COUNT()
            FROM Invoice__c
            WHERE Subscription__c = :sub.Id
        ];

        System.assertEquals(
            1,
            secondCount,
            'Duplicate invoice should not be created'
        );
    }

    @IsTest
    static void testInvoiceBatch() {

        Test.startTest();

        Database.executeBatch(
            new InvoiceBatch(),
            200
        );

        Test.stopTest();

        Integer invoiceCount = [
            SELECT COUNT()
            FROM Invoice__c
        ];

        System.assertEquals(
            3,
            invoiceCount,
            'Batch should generate invoices'
        );
    }

    @IsTest
    static void testInvoiceScheduler() {

        String cronExpression =
            '0 0 1 1 1 ? 2099';

        Test.startTest();

        String jobId = System.schedule(
            'Test Invoice Scheduler',
            cronExpression,
            new InvoiceScheduler()
        );

        Test.stopTest();

        CronTrigger scheduledJob = [
            SELECT Id,
                   CronJobDetail.Name
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertEquals(
            'Test Invoice Scheduler',
            scheduledJob.CronJobDetail.Name
        );
    }
}