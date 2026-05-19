import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateInvoice from '@salesforce/apex/GenerateInvoiceQuickActionController.generateInvoice';

export default class GenerateInvoiceQuickAction extends LightningElement {
    @api recordId;
    hasRun = false;

    @api
    invoke() {
        if (this.hasRun) {
            return;
        }
        this.hasRun = true;
        this.runAction();
    }

    async runAction() {
        try {
            await generateInvoice({ opportunityId: this.recordId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Invoice generated',
                    message: 'Invoice PDF was created and attached to Opportunity.',
                    variant: 'success'
                })
            );
        } catch (error) {
            const message =
                error?.body?.message || 'Unable to generate invoice.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message,
                    variant: 'error'
                })
            );
        }
    }
}
