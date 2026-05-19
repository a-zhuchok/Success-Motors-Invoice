import { LightningElement, api } from 'lwc';
import getAccountSummaries from '@salesforce/apex/CustomerSummaryController.getAccountSummaries';
import getOpportunityProducts from '@salesforce/apex/CustomerSummaryController.getOpportunityProducts';

const OPPORTUNITY_COLUMNS = [
    {
        label: 'Opportunity Name',
        fieldName: 'opportunityUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'name' },
            target: '_blank'
        }
    },
    {
        label: 'Created Date',
        fieldName: 'createdDate',
        type: 'date',
        typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' }
    },
    {
        label: 'Close Date',
        fieldName: 'closeDate',
        type: 'date',
        typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' }
    },
    {
        label: 'Amount',
        fieldName: 'amount',
        type: 'currency'
    },
    {
        type: 'button',
        typeAttributes: {
            label: 'Products',
            name: 'products',
            variant: 'brand'
        }
    }
];

const PRODUCT_COLUMNS = [
    { label: 'Product', fieldName: 'productName', type: 'text' },
    { label: 'Quantity', fieldName: 'quantity', type: 'number' },
    { label: 'Unit Price', fieldName: 'unitPrice', type: 'currency' },
    { label: 'Total', fieldName: 'totalPrice', type: 'currency' }
];

export default class CustomerSummary extends LightningElement {
    @api recordId;

    isLoading = false;
    isProductsLoading = false;
    errorMessage;

    accountNameSearch = '';
    closedTotalSearch;
    pageNumber = 1;
    pageSize = 10;
    totalCount = 0;

    accountRows = [];
    opportunityColumns = OPPORTUNITY_COLUMNS;
    productColumns = PRODUCT_COLUMNS;
    products = [];
    isProductsModalOpen = false;
    modalTitle = 'Sold Products';

    connectedCallback() {
        this.loadData();
    }

    get isRecordPageMode() {
        return !!this.recordId;
    }

    get showListControls() {
        return !this.isRecordPageMode;
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.totalCount / this.pageSize));
    }

    get isPrevDisabled() {
        return this.pageNumber <= 1 || this.isLoading;
    }

    get isNextDisabled() {
        return this.pageNumber >= this.totalPages || this.isLoading;
    }

    get hasAccounts() {
        return this.accountRows.length > 0;
    }

    get pageInfoLabel() {
        return `Page ${this.pageNumber} of ${this.totalPages}`;
    }

    async loadData() {
        this.isLoading = true;
        this.errorMessage = null;
        try {
            const response = await getAccountSummaries({
                accountId: this.recordId || null,
                accountNameSearch: this.isRecordPageMode ? null : this.accountNameSearch,
                closedTotalSearch: this.isRecordPageMode ? null : this.closedTotalSearch,
                pageSize: this.pageSize,
                pageNumber: this.pageNumber
            });
            this.totalCount = response?.totalCount || 0;
            const rows = response?.accounts || [];
            this.accountRows = rows.map((row) => ({
                ...row,
                sectionLabel: `${row.accountName} - ${this.formatCurrency(row.closedTotalAmount)}`,
                opportunities: (row.opportunities || []).map((opp) => ({
                    ...opp,
                    opportunityUrl: `/${opp.id}`
                }))
            }));
        } catch (error) {
            this.errorMessage = error?.body?.message || 'Failed to load customer summary.';
            this.accountRows = [];
            this.totalCount = 0;
        } finally {
            this.isLoading = false;
        }
    }

    handleAccountSearchChange(event) {
        this.accountNameSearch = event.target.value;
    }

    handleTotalSearchChange(event) {
        const value = event.target.value;
        this.closedTotalSearch = value === '' || value === null ? null : Number(value);
    }

    handleSearch() {
        this.pageNumber = 1;
        this.loadData();
    }

    handleReset() {
        this.accountNameSearch = '';
        this.closedTotalSearch = null;
        this.pageNumber = 1;
        this.loadData();
    }

    handlePrevPage() {
        if (this.pageNumber > 1) {
            this.pageNumber -= 1;
            this.loadData();
        }
    }

    handleNextPage() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber += 1;
            this.loadData();
        }
    }

    async handleOpportunityRowAction(event) {
        if (event.detail.action?.name !== 'products') {
            return;
        }
        const row = event.detail.row;
        if (!row?.id) {
            return;
        }

        this.isProductsLoading = true;
        this.isProductsModalOpen = true;
        this.modalTitle = `Products - ${row.name}`;
        this.products = [];
        try {
            this.products = await getOpportunityProducts({ opportunityId: row.id });
        } catch (error) {
            this.products = [];
            this.errorMessage = error?.body?.message || 'Failed to load products.';
        } finally {
            this.isProductsLoading = false;
        }
    }

    closeProductsModal() {
        this.isProductsModalOpen = false;
    }

    formatCurrency(value) {
        const numberValue = value || 0;
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(numberValue);
    }
}
