@IsTest
private class CustomerSummaryControllerTest {
    @IsTest
    static void listModeSupportsPaginationAndFilters() {
        String closedStage = getClosedWonStageName();
        Account a1 = new Account(Name = 'Acme One');
        Account a2 = new Account(Name = 'Acme Two');
        insert new List<Account>{a1, a2};

        Opportunity opp1 = new Opportunity(
            Name = 'A1 Closed',
            StageName = closedStage,
            CloseDate = Date.today(),
            AccountId = a1.Id,
            Amount = 100
        );
        Opportunity opp2 = new Opportunity(
            Name = 'A2 Closed',
            StageName = closedStage,
            CloseDate = Date.today(),
            AccountId = a2.Id,
            Amount = 200
        );
        insert new List<Opportunity>{opp1, opp2};

        CustomerSummaryController.SummaryResponse response =
            CustomerSummaryController.getAccountSummaries(null, 'Acme', null, 10, 1);
        System.assertEquals(2, response.totalCount);
        System.assertEquals(2, response.accounts.size());

        CustomerSummaryController.SummaryResponse filteredByTotal =
            CustomerSummaryController.getAccountSummaries(null, null, 200, 10, 1);
        System.assertEquals(1, filteredByTotal.totalCount);
        System.assertEquals('Acme Two', filteredByTotal.accounts[0].accountName);
    }

    @IsTest
    static void recordPageModeReturnsSingleAccount() {
        String closedStage = getClosedWonStageName();
        Account acc = new Account(Name = 'Single Account');
        insert acc;

        insert new Opportunity(
            Name = 'Single Closed',
            StageName = closedStage,
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Amount = 350
        );

        CustomerSummaryController.SummaryResponse response =
            CustomerSummaryController.getAccountSummaries(acc.Id, null, null, 10, 1);

        System.assertEquals(1, response.totalCount);
        System.assertEquals(1, response.accounts.size());
        System.assertEquals('Single Account', response.accounts[0].accountName);
        System.assertEquals(350, response.accounts[0].closedTotalAmount);
        System.assertEquals(1, response.accounts[0].opportunities.size());
    }

    @IsTest
    static void loadsOpportunityProducts() {
        String closedStage = getClosedWonStageName();
        Account acc = new Account(Name = 'Products Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'With Products',
            StageName = closedStage,
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Amount = 100
        );
        insert opp;

        Id standardPricebookId = Test.getStandardPricebookId();
        Product2 product = new Product2(Name = 'Test Product', IsActive = true);
        insert product;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 50,
            IsActive = true
        );
        insert pbe;

        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 50
        );

        List<CustomerSummaryController.ProductRow> products =
            CustomerSummaryController.getOpportunityProducts(opp.Id);
        System.assertEquals(1, products.size());
        System.assertEquals('Test Product', products[0].productName);
        System.assertEquals(100, products[0].totalPrice);
    }

    private static String getClosedWonStageName() {
        List<OpportunityStage> stages = [
            SELECT MasterLabel
            FROM OpportunityStage
            WHERE IsClosed = true
            AND IsWon = true
            ORDER BY SortOrder ASC
            LIMIT 1
        ];
        return stages.isEmpty() ? 'Closed Won' : stages[0].MasterLabel;
    }
}
