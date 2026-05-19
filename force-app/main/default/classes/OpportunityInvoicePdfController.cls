public with sharing class OpportunityInvoicePdfController {
    public class OrgInfoDTO {
        public String Name { get; set; }
        public String Country { get; set; }
        public String City { get; set; }
        public String Street { get; set; }
    }

    public Opportunity opportunityRecord { get; private set; }
    public Date invoiceDate { get; private set; }
    public String primaryContactName { get; private set; }
    public String primaryContactPhone { get; private set; }
    public String primaryContactEmail { get; private set; }
    public List<OpportunityLineItem> lineItems { get; private set; }
    public Decimal grandTotal { get; private set; }
    public OrgInfoDTO orgInfo { get; private set; }

    public OpportunityInvoicePdfController(ApexPages.StandardController controller) {
        Id opportunityId = controller.getId();

        opportunityRecord = [
            SELECT Id, Name, Owner.Name, Account.Name, Invoice_Number__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        List<OpportunityContactRole> roles = [
            SELECT Contact.Name, Contact.Phone, Contact.Email
            FROM OpportunityContactRole
            WHERE OpportunityId = :opportunityId
            AND IsPrimary = true
            LIMIT 1
        ];

        if (!roles.isEmpty() && roles[0].Contact != null) {
            primaryContactName = roles[0].Contact.Name;
            primaryContactPhone = roles[0].Contact.Phone;
            primaryContactEmail = roles[0].Contact.Email;
        } else {
            primaryContactName = '';
            primaryContactPhone = '';
            primaryContactEmail = '';
        }

        lineItems = [
            SELECT Quantity, UnitPrice, TotalPrice, PricebookEntry.Name
            FROM OpportunityLineItem
            WHERE OpportunityId = :opportunityId
            ORDER BY CreatedDate ASC
        ];

        grandTotal = 0;
        for (OpportunityLineItem lineItem : lineItems) {
            grandTotal += lineItem.TotalPrice == null ? 0 : lineItem.TotalPrice;
        }

        Organization org = [
            SELECT Name, Country, City, Street
            FROM Organization
            LIMIT 1
        ];
        orgInfo = new OrgInfoDTO();
        orgInfo.Name = org.Name;
        orgInfo.Country = org.Country;
        orgInfo.City = org.City;
        orgInfo.Street = org.Street;

        invoiceDate = Date.today();
    }
}
