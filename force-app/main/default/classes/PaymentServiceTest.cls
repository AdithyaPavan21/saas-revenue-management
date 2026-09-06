@IsTest
private class PaymentServiceTest {

    @TestSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Payment Test Account'
        );
        insert acc;

        Subscription__c sub = new Subscription__c(
            Account__c = acc.Id,
            Status__c = 'Active',
            Billing_Frequency__c = 'Monthly',
            Subscription_Amount__c = 1000,
            Next_Billing_Date__c = Date.today()
        );
        insert sub;

        Invoice__c inv = new Invoice__c(
            Subscription__c = sub.Id,
            Account__c = acc.Id,
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today().addDays(7),
            Billing_Period_Start__c = Date.today(),
            Billing_Period_End__c = Date.today().addMonths(1).addDays(-1),
            Amount__c = 1000,
            Tax__c = 180,
            Status__c = 'Pending',
            Billing_Cycle_Key__c = sub.Id + '-TEST'
        );
        insert inv;
    }

    @IsTest
    static void testSuccessfulPayment() {

        Invoice__c inv = [
            SELECT Id, Total_Amount__c
            FROM Invoice__c
            LIMIT 1
        ];

        Test.startTest();

        Payment__c payment = PaymentService.processPayment(
            inv.Id,
            inv.Total_Amount__c,
            'UPI',
            'TXN-SUCCESS-001'
        );

        Test.stopTest();

        System.assertNotEquals(null, payment.Id);

        Payment__c savedPayment = [
            SELECT Status__c,
                   Amount__c,
                   Transaction_ID__c,
                   Invoice__c
            FROM Payment__c
            WHERE Id = :payment.Id
        ];

        System.assertEquals('Successful', savedPayment.Status__c);
        System.assertEquals(inv.Total_Amount__c, savedPayment.Amount__c);
        System.assertEquals('TXN-SUCCESS-001', savedPayment.Transaction_ID__c);
        System.assertEquals(inv.Id, savedPayment.Invoice__c);

        Invoice__c updatedInvoice = [
            SELECT Status__c,
                   Payment_Date__c
            FROM Invoice__c
            WHERE Id = :inv.Id
        ];

        System.assertEquals('Paid', updatedInvoice.Status__c);
        System.assertEquals(Date.today(), updatedInvoice.Payment_Date__c);
    }

    @IsTest
    static void testIncorrectPaymentAmount() {

        Invoice__c inv = [
            SELECT Id, Total_Amount__c
            FROM Invoice__c
            LIMIT 1
        ];

        try {

            PaymentService.processPayment(
                inv.Id,
                inv.Total_Amount__c - 1,
                'UPI',
                'TXN-WRONG-AMOUNT'
            );

            System.assert(false, 'Expected exception was not thrown.');

        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void testDuplicateTransaction() {

        Invoice__c inv = [
            SELECT Id, Total_Amount__c
            FROM Invoice__c
            LIMIT 1
        ];

        Payment__c existingPayment = new Payment__c(
            Invoice__c = inv.Id,
            Amount__c = inv.Total_Amount__c,
            Status__c = 'Successful',
            Payment_Method__c = 'UPI',
            Transaction_ID__c = 'TXN-DUPLICATE',
            Payment_Date__c = System.now()
        );
        insert existingPayment;

        try {

            PaymentService.processPayment(
                inv.Id,
                inv.Total_Amount__c,
                'UPI',
                'TXN-DUPLICATE'
            );

            System.assert(false, 'Expected duplicate transaction exception.');

        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void testAlreadyPaidInvoice() {

        Invoice__c inv = [
            SELECT Id, Total_Amount__c
            FROM Invoice__c
            LIMIT 1
        ];

        inv.Status__c = 'Paid';
        inv.Payment_Date__c = Date.today();
        update inv;

        try {

            PaymentService.processPayment(
                inv.Id,
                inv.Total_Amount__c,
                'UPI',
                'TXN-PAID-INVOICE'
            );

            System.assert(false, 'Expected already-paid exception.');

        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}