public with sharing class CustomerSummaryController {
    public class SummaryResponse {
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public List<AccountSummaryRow> accounts;
    }

    public class AccountSummaryRow {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Decimal closedTotalAmount;
        @AuraEnabled public List<OpportunityRow> opportunities;
    }

    public class OpportunityRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Date closeDate;
        @AuraEnabled public Decimal amount;
    }

    public class ProductRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal totalPrice;
    }

    @AuraEnabled(cacheable=true)
    public static SummaryResponse getAccountSummaries(
        Id accountId,
        String accountNameSearch,
        Decimal closedTotalSearch,
        Integer pageSize,
        Integer pageNumber
    ) {
        Integer normalizedPageSize = pageSize == null || pageSize <= 0 ? 10 : pageSize;
        Integer normalizedPageNumber = pageNumber == null || pageNumber <= 0 ? 1 : pageNumber;

        if (accountId != null) {
            return getSingleAccountSummary(accountId);
        }

        String likeName = String.isBlank(accountNameSearch) ? null : '%' + accountNameSearch.trim() + '%';

        String baseQuery =
            ' FROM Opportunity ' +
            ' WHERE IsClosed = true AND AccountId != null ';
        if (likeName != null) {
            baseQuery += ' AND Account.Name LIKE :likeName ';
        }

        String groupBy =
            ' GROUP BY AccountId, Account.Name ';

        String havingClause = '';
        if (closedTotalSearch != null) {
            havingClause = ' HAVING SUM(Amount) = :closedTotalSearch ';
        }

        String countQuery =
            'SELECT AccountId accId, Account.Name accName, SUM(Amount) totalAmount' +
            baseQuery +
            groupBy +
            havingClause +
            ' ORDER BY Account.Name ';

        List<AggregateResult> allAggregate = Database.query(countQuery);

        SummaryResponse response = new SummaryResponse();
        response.totalCount = allAggregate.size();
        response.accounts = new List<AccountSummaryRow>();

        if (allAggregate.isEmpty()) {
            return response;
        }

        Integer offsetRows = (normalizedPageNumber - 1) * normalizedPageSize;
        String pagedQuery = countQuery + ' LIMIT :normalizedPageSize OFFSET :offsetRows';
        List<AggregateResult> pageAggregate = Database.query(pagedQuery);

        Map<Id, Decimal> totalByAccountId = new Map<Id, Decimal>();
        List<Id> accountIds = new List<Id>();
        for (AggregateResult ar : pageAggregate) {
            Id accId = (Id) ar.get('accId');
            if (accId == null) {
                continue;
            }
            accountIds.add(accId);
            totalByAccountId.put(accId, (Decimal) ar.get('totalAmount'));
        }

        Map<Id, List<OpportunityRow>> oppRowsByAccountId = buildClosedOpportunityRows(accountIds);

        for (AggregateResult ar : pageAggregate) {
            Id accId = (Id) ar.get('accId');
            if (accId == null) {
                continue;
            }
            AccountSummaryRow row = new AccountSummaryRow();
            row.accountId = accId;
            row.accountName = (String) ar.get('accName');
            row.closedTotalAmount = totalByAccountId.get(accId);
            row.opportunities = oppRowsByAccountId.containsKey(accId)
                ? oppRowsByAccountId.get(accId)
                : new List<OpportunityRow>();
            response.accounts.add(row);
        }

        return response;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductRow> getOpportunityProducts(Id opportunityId) {
        if (opportunityId == null) {
            return new List<ProductRow>();
        }

        List<ProductRow> result = new List<ProductRow>();
        for (OpportunityLineItem oli : [
            SELECT Id, Quantity, UnitPrice, TotalPrice, PricebookEntry.Product2.Name
            FROM OpportunityLineItem
            WHERE OpportunityId = :opportunityId
            ORDER BY CreatedDate ASC
        ]) {
            ProductRow row = new ProductRow();
            row.id = oli.Id;
            row.productName = oli.PricebookEntry != null && oli.PricebookEntry.Product2 != null
                ? oli.PricebookEntry.Product2.Name
                : '';
            row.quantity = oli.Quantity;
            row.unitPrice = oli.UnitPrice;
            row.totalPrice = oli.TotalPrice;
            result.add(row);
        }
        return result;
    }

    private static SummaryResponse getSingleAccountSummary(Id accountId) {
        SummaryResponse response = new SummaryResponse();
        response.accounts = new List<AccountSummaryRow>();

        List<Account> accounts = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            response.totalCount = 0;
            return response;
        }

        Decimal closedTotalAmount = 0;
        List<AggregateResult> totals = [
            SELECT SUM(Amount) totalAmount
            FROM Opportunity
            WHERE IsClosed = true
            AND AccountId = :accountId
        ];
        if (!totals.isEmpty() && totals[0].get('totalAmount') != null) {
            closedTotalAmount = (Decimal) totals[0].get('totalAmount');
        }

        AccountSummaryRow row = new AccountSummaryRow();
        row.accountId = accounts[0].Id;
        row.accountName = accounts[0].Name;
        row.closedTotalAmount = closedTotalAmount;
        Map<Id, List<OpportunityRow>> oppRowsByAccountId =
            buildClosedOpportunityRows(new List<Id>{accountId});
        row.opportunities = oppRowsByAccountId.containsKey(accountId)
            ? oppRowsByAccountId.get(accountId)
            : new List<OpportunityRow>();

        response.accounts.add(row);
        response.totalCount = 1;
        return response;
    }

    private static Map<Id, List<OpportunityRow>> buildClosedOpportunityRows(List<Id> accountIds) {
        Map<Id, List<OpportunityRow>> result = new Map<Id, List<OpportunityRow>>();
        if (accountIds == null || accountIds.isEmpty()) {
            return result;
        }

        for (Opportunity opp : [
            SELECT Id, Name, CreatedDate, CloseDate, Amount, AccountId
            FROM Opportunity
            WHERE IsClosed = true
            AND AccountId IN :accountIds
            ORDER BY CreatedDate DESC
        ]) {
            if (!result.containsKey(opp.AccountId)) {
                result.put(opp.AccountId, new List<OpportunityRow>());
            }
            OpportunityRow row = new OpportunityRow();
            row.id = opp.Id;
            row.name = opp.Name;
            row.createdDate = opp.CreatedDate;
            row.closeDate = opp.CloseDate;
            row.amount = opp.Amount;
            result.get(opp.AccountId).add(row);
        }
        return result;
    }
}
