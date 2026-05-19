@IsTest
private class GenerateInvoiceQuickActionControllerTest {
    @IsTest
    static void createAndVersionInvoiceFile() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        Test.startTest();
        GenerateInvoiceQuickActionController.generateInvoice(opp.Id);
        GenerateInvoiceQuickActionController.generateInvoice(opp.Id);
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opp.Id
        ];
        System.assertEquals(1, links.size(), 'Only one document should be linked to Opportunity.');

        List<ContentVersion> versions = [
            SELECT Id
            FROM ContentVersion
            WHERE ContentDocumentId = :links[0].ContentDocumentId
        ];
        System.assertEquals(2, versions.size(), 'Second execution should create a new file version.');
    }

    @IsTest
    static void throwsWhenOpportunityIdIsMissing() {
        try {
            GenerateInvoiceQuickActionController.generateInvoice(null);
            System.assert(false, 'Expected exception for missing Opportunity Id.');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Opportunity Id is required.'));
        }
    }
}
