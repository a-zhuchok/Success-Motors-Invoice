public with sharing class OpportunityInvoiceController {
    @AuraEnabled
    public static void generate(Id opportunityId) {
        GenerateInvoiceQuickActionController.generateInvoice(opportunityId);
    }
}
