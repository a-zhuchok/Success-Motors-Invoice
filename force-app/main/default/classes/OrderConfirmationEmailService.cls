global with sharing class OrderConfirmationEmailService implements Messaging.InboundEmailHandler {
    @TestVisible
    private static Set<String> waitingStageNames = new Set<String>{
        'Prospecting',
        'Pending Confirmation',
        'Ожидание подтверждения заказа'
    };

    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        result.success = true;

        String source = buildSourceText(email);
        String invoiceNumber = extractInvoiceNumber(source);
        if (String.isBlank(invoiceNumber)) {
            return result;
        }

        String decision = extractDecision(source);
        if (String.isBlank(decision)) {
            return result;
        }

        List<Opportunity> opportunities = [
            SELECT Id, StageName, Invoice_Number__c
            FROM Opportunity
            WHERE Invoice_Number__c = :invoiceNumber
            LIMIT 1
        ];

        if (opportunities.isEmpty()) {
            return result;
        }

        Opportunity opp = opportunities[0];
        if (!isWaitingForConfirmation(opp.StageName)) {
            return result;
        }

        if (decision == 'REJECTED') {
            String closedLostStage = getClosedLostStageName();
            if (!String.isBlank(closedLostStage)) {
                opp.StageName = closedLostStage;
                update opp;
            }
            return result;
        }

        String nextStageName = getNextStageName(opp.StageName);
        if (!String.isBlank(nextStageName)) {
            opp.StageName = nextStageName;
            update opp;
        }

        return result;
    }

    private static String buildSourceText(Messaging.InboundEmail email) {
        String source = '';
        source += email != null && email.subject != null ? email.subject + '\n' : '';
        source += email != null && email.plainTextBody != null ? email.plainTextBody + '\n' : '';
        source += email != null && email.htmlBody != null ? email.htmlBody : '';
        return source;
    }

    private static String extractInvoiceNumber(String source) {
        if (String.isBlank(source)) {
            return null;
        }
        Matcher matcher = Pattern.compile('(?i)INV-\\d{6}').matcher(source);
        return matcher.find() ? matcher.group(0).toUpperCase() : null;
    }

    private static String extractDecision(String source) {
        if (String.isBlank(source)) {
            return null;
        }
        String upper = source.toUpperCase();
        if (upper.contains('APPROVED')) {
            return 'APPROVED';
        }
        if (upper.contains('REJECTED')) {
            return 'REJECTED';
        }
        return null;
    }

    private static Boolean isWaitingForConfirmation(String stageName) {
        return !String.isBlank(stageName) && waitingStageNames.contains(stageName);
    }

    private static String getNextStageName(String currentStageName) {
        List<OpportunityStage> currentStages = [
            SELECT SortOrder
            FROM OpportunityStage
            WHERE MasterLabel = :currentStageName
            LIMIT 1
        ];
        if (currentStages.isEmpty()) {
            return null;
        }

        List<OpportunityStage> nextStages = [
            SELECT MasterLabel
            FROM OpportunityStage
            WHERE SortOrder > :currentStages[0].SortOrder
            AND IsActive = true
            ORDER BY SortOrder ASC
            LIMIT 1
        ];
        return nextStages.isEmpty() ? null : nextStages[0].MasterLabel;
    }

    private static String getClosedLostStageName() {
        List<OpportunityStage> closedLost = [
            SELECT MasterLabel
            FROM OpportunityStage
            WHERE IsClosed = true
            AND IsWon = false
            ORDER BY SortOrder ASC
            LIMIT 1
        ];
        return closedLost.isEmpty() ? null : closedLost[0].MasterLabel;
    }
}
