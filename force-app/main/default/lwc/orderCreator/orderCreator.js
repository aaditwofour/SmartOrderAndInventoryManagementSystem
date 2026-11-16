import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createOrder from '@salesforce/apex/OrderCreationController.createOrder';

export default class OrderCreator extends NavigationMixin(LightningElement) {
    customerId;
    lines = [{ key: 1, productId: null, quantity: 1 }];
    nextKey = 2;
    isBusy = false;

    get isOnlyLine() {
        return this.lines.length === 1;
    }

    get disableCreate() {
        return this.isBusy || !this.customerId || this.lines.some((line) => !line.productId || !line.quantity || line.quantity < 1);
    }

    handleCustomerChange(event) {
        this.customerId = event.detail.recordId;
    }

    handleProductChange(event) {
        const key = Number(event.target.dataset.key);
        this.lines = this.lines.map((line) => line.key === key ? { ...line, productId: event.detail.recordId } : line);
    }

    handleQuantityChange(event) {
        const key = Number(event.target.dataset.key);
        const quantity = Number(event.target.value);
        this.lines = this.lines.map((line) => line.key === key ? { ...line, quantity } : line);
    }

    addLine() {
        this.lines = [...this.lines, { key: this.nextKey++, productId: null, quantity: 1 }];
    }

    removeLine(event) {
        const key = Number(event.currentTarget.dataset.key);
        this.lines = this.lines.filter((line) => line.key !== key);
    }

    async handleCreate() {
        const inputs = [...this.template.querySelectorAll('lightning-input')];
        if (inputs.some((input) => !input.reportValidity())) return;
        this.isBusy = true;
        try {
            const orderId = await createOrder({
                customerId: this.customerId,
                lines: this.lines.map(({ productId, quantity }) => ({ productId, quantity }))
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Order submitted',
                message: 'The order was created and submitted for processing or approval.',
                variant: 'success'
            }));
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: orderId, objectApiName: 'Sales_Order__c', actionName: 'view' }
            });
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Could not create order',
                message: error?.body?.message || 'Please check the customer, products, and quantities.',
                variant: 'error'
            }));
        } finally {
            this.isBusy = false;
        }
    }
}
