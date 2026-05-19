import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { wire } from 'lwc';
import getPrefillData from '@salesforce/apex/SendInvoiceQuickActionController.getPrefillData';
import sendInvoice from '@salesforce/apex/SendInvoiceQuickActionController.sendInvoice';

export default class SendInvoiceQuickAction extends NavigationMixin(LightningElement) {
    _recordId;

    isLoading = true;
    isSending = false;
    isInitialized = false;

    subject = '';
    body = '';
    recipientName = '';
    recipientEmail = '';
    invoiceNumber = '';
    contentDocumentId;

    connectedCallback() {
        this.isInitialized = false;
    }

    @api
    set recordId(value) {
        if (value && value !== this._recordId) {
            this.isInitialized = false;
        }
        this._recordId = value;
        this.tryInitialize();
    }

    get recordId() {
        return this._recordId;
    }

    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        if (!this._recordId) {
            const state = pageRef?.state || {};
            this._recordId =
                state.recordId ||
                state.c__recordId ||
                this.extractRecordIdFromBackgroundContext(state.backgroundContext);
            if (!this._recordId) {
                this._recordId = this.extractRecordIdFromUrl();
            }
        }
        this.tryInitialize();
    }

    tryInitialize() {
        if (this._recordId && !this.isInitialized) {
            this.isInitialized = true;
            this.loadData();
        }
    }

    extractRecordIdFromBackgroundContext(backgroundContext) {
        if (!backgroundContext) {
            return null;
        }
        let decoded = backgroundContext;
        try {
            decoded = decodeURIComponent(backgroundContext);
        } catch (e) {
        }
        const match = decoded.match(/\/([a-zA-Z0-9]{15,18})(?:\/|$)/);
        return match ? match[1] : null;
    }

    extractRecordIdFromUrl() {
        const path = window?.location?.pathname || '';
        const match = path.match(/\/([a-zA-Z0-9]{15,18})(?:\/|$)/);
        return match ? match[1] : null;
    }

    async loadData() {
        this.isLoading = true;
        try {
            const data = await getPrefillData({ opportunityId: this.recordId });
            this.subject = data.subject || '';
            this.body = data.body || '';
            this.recipientName = data.recipientName || '';
            this.recipientEmail = data.recipientEmail || '';
            this.invoiceNumber = data.invoiceNumber || '';
            this.contentDocumentId = data.contentDocumentId;
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
            this.dispatchEvent(new CloseActionScreenEvent());
        } finally {
            this.isLoading = false;
        }
    }

    handleBodyChange(event) {
        this.body = event.target.value;
    }

    handlePreview() {
        if (!this.contentDocumentId) {
            this.showToast('Error', 'Generated invoice file was not found.', 'error');
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: this.contentDocumentId
            }
        });
    }

    async handleSend() {
        this.isSending = true;
        try {
            await sendInvoice({
                opportunityId: this.recordId,
                body: this.body
            });
            this.showToast('Success', 'Invoice email was sent.', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isSending = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    get isPreviewDisabled() {
        return !this.contentDocumentId || this.isLoading || this.isSending;
    }

    get isSendDisabled() {
        return this.isLoading || this.isSending;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    getErrorMessage(error) {
        return error?.body?.message || 'Unexpected error occurred.';
    }
}
