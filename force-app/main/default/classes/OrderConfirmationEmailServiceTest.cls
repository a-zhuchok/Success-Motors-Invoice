@IsTest
private class OrderConfirmationEmailServiceTest {
    @IsTest
    static void approvedMovesOpportunityToNextStage() {
        String waitingStage = getOpenStageName();
        String nextStage = getNextStageName(waitingStage);
        if (String.isBlank(nextStage)) {
            return;
        }

        Opportunity opp = createOpportunity(waitingStage);

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Order confirmation ' + opp.Invoice_Number__c;
        email.plainTextBody = 'Approved';

        Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
        envelope.fromAddress = 'client@example.com';

        Test.startTest();
        new OrderConfirmationEmailService().handleInboundEmail(email, envelope);
        Test.stopTest();

        Opportunity updated = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(nextStage, updated.StageName);
    }

    @IsTest
    static void rejectedMovesOpportunityToClosedLost() {
        String waitingStage = getOpenStageName();
        String closedLostStage = getClosedLostStageName();
        if (String.isBlank(closedLostStage)) {
            return;
        }

        Opportunity opp = createOpportunity(waitingStage);

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Invoice ' + opp.Invoice_Number__c;
        email.plainTextBody = 'Rejected';

        Test.startTest();
        new OrderConfirmationEmailService().handleInboundEmail(email, new Messaging.InboundEnvelope());
        Test.stopTest();

        Opportunity updated = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(closedLostStage, updated.StageName);
    }

    @IsTest
    static void doesNothingWhenDecisionOrInvoiceMissing() {
        String waitingStage = getOpenStageName();
        Opportunity opp = createOpportunity(waitingStage);

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = 'Random subject';
        email.plainTextBody = 'No decision here';

        new OrderConfirmationEmailService().handleInboundEmail(email, new Messaging.InboundEnvelope());

        Opportunity unchanged = [SELECT StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(waitingStage, unchanged.StageName);
    }

    private static Opportunity createOpportunity(String stageName) {
        Account acc = new Account(Name = 'Email Service Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Inbound Confirmation',
            StageName = stageName,
            CloseDate = Date.today().addDays(5),
            AccountId = acc.Id
        );
        insert opp;
        return [SELECT Id, Invoice_Number__c FROM Opportunity WHERE Id = :opp.Id];
    }

    private static String getOpenStageName() {
        List<OpportunityStage> stages = [
            SELECT MasterLabel
            FROM OpportunityStage
            WHERE IsActive = true
            AND IsClosed = false
            ORDER BY SortOrder ASC
            LIMIT 1
        ];
        return stages.isEmpty() ? null : stages[0].MasterLabel;
    }

    private static String getNextStageName(String currentStageName) {
        List<OpportunityStage> current = [
            SELECT SortOrder
            FROM OpportunityStage
            WHERE MasterLabel = :currentStageName
            LIMIT 1
        ];
        if (current.isEmpty()) {
            return null;
        }
        List<OpportunityStage> next = [
            SELECT MasterLabel
            FROM OpportunityStage
            WHERE IsActive = true
            AND SortOrder > :current[0].SortOrder
            ORDER BY SortOrder ASC
            LIMIT 1
        ];
        return next.isEmpty() ? null : next[0].MasterLabel;
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
