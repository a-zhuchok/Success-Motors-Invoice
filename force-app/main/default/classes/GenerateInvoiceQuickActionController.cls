public with sharing class GenerateInvoiceQuickActionController {
    @AuraEnabled
    public static void generateInvoice(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }

        Opportunity opp = [
            SELECT Id, Invoice_Number__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        if (String.isBlank(opp.Invoice_Number__c)) {
            throw new AuraHandledException(
                'Invoice Number is empty for this Opportunity. Save the record and try again.'
            );
        }

        PageReference pdfPage = Page.OpportunityInvoicePdf;
        pdfPage.getParameters().put('id', opp.Id);

        Blob pdfData = Test.isRunningTest()
            ? Blob.valueOf('Test PDF')
            : pdfPage.getContentAsPDF();

        String title = opp.Invoice_Number__c;
        String fileName = title + '.pdf';

        List<ContentDocumentLink> existingLinks = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opp.Id
            AND ContentDocument.Title = :title
            ORDER BY ContentDocument.LastModifiedDate DESC
            LIMIT 1
        ];

        ContentVersion nextVersion = new ContentVersion(
            Title = title,
            PathOnClient = fileName,
            VersionData = pdfData
        );

        if (!existingLinks.isEmpty()) {
            nextVersion.ContentDocumentId = existingLinks[0].ContentDocumentId;
        } else {
            nextVersion.FirstPublishLocationId = opp.Id;
        }

        insert nextVersion;
    }
}
