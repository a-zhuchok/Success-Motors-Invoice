public with sharing class SendInvoiceQuickActionController {
    private static final String TEMPLATE_DEVELOPER_NAME = 'Send_Invoice_Template';

    public class PrefillDTO {
        @AuraEnabled public String subject;
        @AuraEnabled public String body;
        @AuraEnabled public String recipientName;
        @AuraEnabled public String recipientEmail;
        @AuraEnabled public String invoiceNumber;
        @AuraEnabled public Id contentDocumentId;
    }

    @AuraEnabled
    public static PrefillDTO getPrefillData(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }

        Opportunity opp = [
            SELECT Id, Name, Invoice_Number__c, Account.Name
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        if (String.isBlank(opp.Invoice_Number__c)) {
            throw new AuraHandledException(
                'Invoice Number is empty for this Opportunity. Generate invoice first.'
            );
        }

        OpportunityContactRole primaryRole;
        List<OpportunityContactRole> roles = [
            SELECT Contact.Name, Contact.Email
            FROM OpportunityContactRole
            WHERE OpportunityId = :opportunityId
            AND IsPrimary = true
            LIMIT 1
        ];
        if (!roles.isEmpty()) {
            primaryRole = roles[0];
        }

        EmailTemplate templateRecord = [
            SELECT Subject, HtmlValue, Body
            FROM EmailTemplate
            WHERE DeveloperName = :TEMPLATE_DEVELOPER_NAME
            LIMIT 1
        ];

        String rawSubject = templateRecord.Subject;
        String rawBody = templateRecord.Body;
        if (String.isBlank(rawBody) && !String.isBlank(templateRecord.HtmlValue)) {
            rawBody = stripHtml(templateRecord.HtmlValue);
        }

        Organization orgInfo = [SELECT Name FROM Organization LIMIT 1];

        PrefillDTO dto = new PrefillDTO();
        dto.invoiceNumber = opp.Invoice_Number__c;
        dto.recipientName = primaryRole != null && primaryRole.Contact != null
            ? primaryRole.Contact.Name
            : '';
        dto.recipientEmail = primaryRole != null && primaryRole.Contact != null
            ? primaryRole.Contact.Email
            : '';
        dto.subject = applyTemplateTokens(rawSubject, opp, dto.recipientName, orgInfo.Name);
        dto.body = applyTemplateTokens(rawBody, opp, dto.recipientName, orgInfo.Name);
        dto.contentDocumentId = getInvoiceContentDocumentId(opportunityId, opp.Invoice_Number__c);
        return dto;
    }

    @AuraEnabled
    public static void sendInvoice(Id opportunityId, String body) {
        PrefillDTO dto = getPrefillData(opportunityId);

        if (String.isBlank(dto.recipientEmail)) {
            throw new AuraHandledException('Primary contact email is required to send invoice.');
        }

        if (dto.contentDocumentId == null) {
            throw new AuraHandledException('Invoice file was not found on this Opportunity.');
        }

        ContentVersion latestVersion = [
            SELECT Title, FileExtension, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :dto.contentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];

        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setBody(latestVersion.VersionData);
        attachment.setFileName(
            latestVersion.Title +
            (String.isBlank(latestVersion.FileExtension) ? '' : '.' + latestVersion.FileExtension)
        );

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setToAddresses(new String[] { dto.recipientEmail });
        message.setSubject(dto.subject);
        message.setPlainTextBody(String.isBlank(body) ? dto.body : body);
        message.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });

        Messaging.SendEmailResult[] results = Messaging.sendEmail(
            new Messaging.SingleEmailMessage[] { message }
        );
        if (results == null || results.isEmpty() || !results[0].isSuccess()) {
            String errorMessage = 'Failed to send invoice email.';
            if (results != null && !results.isEmpty() && !results[0].getErrors().isEmpty()) {
                errorMessage = results[0].getErrors()[0].getMessage();
            }
            throw new AuraHandledException(errorMessage);
        }
    }

    private static Id getInvoiceContentDocumentId(Id opportunityId, String invoiceNumber) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :opportunityId
            AND ContentDocument.Title = :invoiceNumber
            ORDER BY ContentDocument.LastModifiedDate DESC
            LIMIT 1
        ];
        return links.isEmpty() ? null : links[0].ContentDocumentId;
    }

    private static String applyTemplateTokens(
        String source,
        Opportunity opp,
        String contactName,
        String orgName
    ) {
        String result = String.isBlank(source) ? '' : source;
        result = result.replace('{INVOICE_NUMBER}', opp.Invoice_Number__c);
        result = result.replace('{OPPORTUNITY_NAME}', opp.Name);
        result = result.replace('{ACCOUNT_NAME}', opp.Account != null ? opp.Account.Name : '');
        result = result.replace('{CONTACT_NAME}', String.isBlank(contactName) ? 'Customer' : contactName);
        result = result.replace('{ORG_NAME}', orgName);
        return result;
    }

    private static String stripHtml(String html) {
        return String.isBlank(html) ? '' : html.replaceAll('<[^>]*>', ' ').replaceAll('\\s+', ' ').trim();
    }
}
