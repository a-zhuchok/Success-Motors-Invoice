@IsTest
private class SendInvoiceQuickActionControllerTest {
    @IsTest
    static void prefillAndSendFlowWorks() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            LastName = 'Primary',
            Email = 'primary@example.com',
            AccountId = acc.Id
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Send Invoice Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        insert new OpportunityContactRole(
            OpportunityId = opp.Id,
            ContactId = con.Id,
            IsPrimary = true,
            Role = 'Decision Maker'
        );

        ContentVersion invoiceVersion = new ContentVersion(
            Title = opp.Invoice_Number__c,
            PathOnClient = opp.Invoice_Number__c + '.pdf',
            VersionData = Blob.valueOf('PDF'),
            FirstPublishLocationId = opp.Id
        );
        insert invoiceVersion;

        Test.startTest();
        SendInvoiceQuickActionController.PrefillDTO dto =
            SendInvoiceQuickActionController.getPrefillData(opp.Id);
        SendInvoiceQuickActionController.sendInvoice(opp.Id, 'Custom body');
        Test.stopTest();

        System.assertEquals(con.Name, dto.recipientName);
        System.assertEquals(con.Email, dto.recipientEmail);
        System.assertEquals(opp.Invoice_Number__c, dto.invoiceNumber);
        System.assertNotEquals(null, dto.contentDocumentId);
    }
}
