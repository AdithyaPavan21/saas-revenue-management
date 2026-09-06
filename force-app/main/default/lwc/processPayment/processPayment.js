import { LightningElement, api, wire } from 'lwc';
import processPayment from '@salesforce/apex/PaymentService.processPayment';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import TOTAL_AMOUNT_FIELD from '@salesforce/schema/Invoice__c.Total_Amount__c';
const INVOICE_FIELDS = [
    'Invoice__c.Total_Amount__c',
    'Invoice__c.Status__c'
];

export default class ProcessPayment extends LightningElement {
    @api recordId;

    paymentMethod;
    transactionId;

    get paymentMethodOptions(){
        return [
            {label: 'Credit Card', value: 'Credit Card'},
            {label: 'Debit Card', value: 'Debit Card'},
            {label: 'UPI', value: 'UPI'},
            {label: 'Bank Transfer', value: 'Bank Transfer'}
        ];
    }

    handleMethodChange(event){
        this.paymentMethod = event.target.value;
    }

    handleTransactionChange(event){
        this.transactionId = event.target.value;
    }
    handleCancel(){
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handlePayment(){
        try {
            await processPayment({
                invoiceId: this.recordId,
                paymentAmount: this.paymentAmount,
                paymentMethod: this.paymentMethod,
                transactionId: this.transactionId
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Payment processed successfully',
                variant: 'success'
            }));
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error processing payment',
                message: error.body.message,
                variant: 'error'
            })
        );
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: [TOTAL_AMOUNT_FIELD] })
    invoice;

    get paymentAmount(){
        return getFieldValue(this.invoice.data, TOTAL_AMOUNT_FIELD);
    }
}
