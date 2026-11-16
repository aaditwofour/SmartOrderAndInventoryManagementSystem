public with sharing class OrderAssistantLookupAction {
    public class Request {
        @InvocableVariable(required=true label='Lookup Type' description='CHECK_STOCK, PENDING_APPROVALS, ORDER_DETAILS, or INVOICE_STATUS')
        public String lookupType;
        @InvocableVariable(label='Product, Order, or Invoice Search Value')
        public String lookupValue;
        @InvocableVariable(label='Verified Customer Email' description='Optional email used to restrict customer order tracking.')
        public String customerEmail;
    }

    public class Response {
        @InvocableVariable(label='Lookup Result')
        public String resultText;
    }

    @InvocableMethod(label='Look Up Order and Inventory Information' description='Read-only inventory, order, approval, and invoice lookups for authorized users.')
    public static List<Response> execute(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null) return responses;

        for (Request request : requests) {
            Response response = new Response();
            response.resultText = handleRequest(request);
            responses.add(response);
        }
        return responses;
    }

    private static String handleRequest(Request request) {
        if (request == null || String.isBlank(request.lookupType)) {
            return 'Choose a lookup type: CHECK_STOCK, PENDING_APPROVALS, ORDER_DETAILS, or INVOICE_STATUS.';
        }

        String typeName = request.lookupType.trim().toUpperCase();
        try {
            if (typeName == 'CHECK_STOCK') return lookupStock(request.lookupValue);
            if (typeName == 'PENDING_APPROVALS') return lookupPendingApprovals();
            if (typeName == 'ORDER_DETAILS') return lookupOrder(request.lookupValue, request.customerEmail);
            if (typeName == 'INVOICE_STATUS') return lookupInvoice(request.lookupValue);
            return 'Unsupported lookup type. Choose CHECK_STOCK, PENDING_APPROVALS, ORDER_DETAILS, or INVOICE_STATUS.';
        } catch (Exception e) {
            return 'The lookup could not be completed. Check record access and try again.';
        }
    }

    private static String lookupStock(String searchValue) {
        if (String.isBlank(searchValue)) return 'Enter a product name or product code.';
        String searchPattern = '%' + searchValue.trim() + '%';
        List<Product__c> products = [
            SELECT Name, Product_Code__c, Unit_Price__c, Available_Quantity__c, Reorder_Level__c, Description__c
            FROM Product__c
            WHERE Active__c = true AND (Name LIKE :searchPattern OR Product_Code__c LIKE :searchPattern)
            WITH USER_MODE
            ORDER BY Name
            LIMIT 10
        ];
        if (products.isEmpty()) return 'No active products matched that search.';

        List<String> summaries = new List<String>();
        for (Product__c product : products) {
            String descText = String.isNotBlank(product.Description__c) ? ' Description: ' + product.Description__c + '.' : '';
            summaries.add(product.Name + ' (' + product.Product_Code__c + '): Price: '
                + String.valueOf(product.Unit_Price__c) + '; '
                + String.valueOf(product.Available_Quantity__c) + ' available; reorder at '
                + String.valueOf(product.Reorder_Level__c) + '.' + descText);
        }
        return String.join(summaries, '\n');
    }

    private static String lookupPendingApprovals() {
        List<Sales_Order__c> orders = [
            SELECT Name, Customer__r.Name, Order_Date__c, Order_Total__c
            FROM Sales_Order__c
            WHERE Approval_Status__c = 'Pending'
            WITH USER_MODE
            ORDER BY Order_Date__c ASC
            LIMIT 20
        ];
        if (orders.isEmpty()) return 'There are no pending approvals visible to you.';

        List<String> summaries = new List<String>();
        for (Sales_Order__c orderRecord : orders) {
            String customerName = orderRecord.Customer__r == null ? 'No customer' : orderRecord.Customer__r.Name;
            summaries.add(orderRecord.Name + ' for ' + customerName + ', total '
                + String.valueOf(orderRecord.Order_Total__c) + ', dated '
                + String.valueOf(orderRecord.Order_Date__c) + '.');
        }
        return String.join(summaries, '\n');
    }

    private static String lookupOrder(String lookupValue, String customerEmail) {
        if (String.isBlank(lookupValue)) return 'Enter a Salesforce order number or record ID.';
        String key = lookupValue.trim();
        String verifiedEmail = String.isBlank(customerEmail) ? null : customerEmail.trim().toLowerCase();
        List<Sales_Order__c> orders;
        if (key.length() == 15 || key.length() == 18) {
            Id orderId = Id.valueOf(key);
            orders = [
                SELECT Name, Customer__r.Name, Customer__r.Email__c, Order_Date__c, Order_Status__c,
                    Approval_Status__c, Order_Total__c, Sync_Status__c
                FROM Sales_Order__c WHERE Id=:orderId AND (:verifiedEmail = null OR Customer__r.Email__c = :verifiedEmail) WITH USER_MODE LIMIT 1
            ];
        } else {
            orders = [
                SELECT Name, Customer__r.Name, Customer__r.Email__c, Order_Date__c, Order_Status__c,
                    Approval_Status__c, Order_Total__c, Sync_Status__c
                FROM Sales_Order__c WHERE Name=:key AND (:verifiedEmail = null OR Customer__r.Email__c = :verifiedEmail) WITH USER_MODE LIMIT 1
            ];
        }
        if (orders.isEmpty()) return 'No matching order was found or the order is not visible to you.';

        Sales_Order__c orderRecord = orders[0];
        String customerName = orderRecord.Customer__r == null ? 'No customer' : orderRecord.Customer__r.Name;
        return orderRecord.Name + ': ' + orderRecord.Order_Status__c + ', approval '
            + orderRecord.Approval_Status__c + ', customer ' + customerName + ', total '
            + String.valueOf(orderRecord.Order_Total__c) + ', sync ' + orderRecord.Sync_Status__c + '.';
    }

    private static String lookupInvoice(String lookupValue) {
        if (String.isBlank(lookupValue)) return 'Enter an invoice number or external invoice ID.';
        String key = lookupValue.trim();
        List<Invoice__c> invoices = [
            SELECT Name, External_Invoice_ID__c, Sync_Status__c, Invoice_Amount__c, Invoice_Date__c
            FROM Invoice__c
            WHERE Name=:key OR External_Invoice_ID__c=:key
            WITH USER_MODE
            ORDER BY Invoice_Date__c DESC
            LIMIT 1
        ];
        if (invoices.isEmpty()) return 'No matching invoice was found or the invoice is not visible to you.';

        Invoice__c invoiceRecord = invoices[0];
        return invoiceRecord.Name + ': sync ' + invoiceRecord.Sync_Status__c + ', external ID '
            + invoiceRecord.External_Invoice_ID__c + ', amount '
            + String.valueOf(invoiceRecord.Invoice_Amount__c) + ', dated '
            + String.valueOf(invoiceRecord.Invoice_Date__c) + '.';
    }
}
