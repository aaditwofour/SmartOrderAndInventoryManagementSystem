public with sharing class AgentforceProductLookupAction {
    public class Request {
        @InvocableVariable(required=true label='Product Search' description='Product name or product code to search for.')
        public String searchText;
    }

    public class Response {
        @InvocableVariable(label='Product Results' description='Matching active products with Salesforce price, available stock, and description.')
        public String resultText;
    }

    @InvocableMethod(label='Find Store Products' description='Search active store products and return live price, available stock, and product description. Read-only.')
    public static List<Response> findProducts(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null) return responses;

        for (Request request : requests) {
            Response response = new Response();
            response.resultText = lookup(request == null ? null : request.searchText);
            responses.add(response);
        }
        return responses;
    }

    private static String lookup(String searchText) {
        if (String.isBlank(searchText)) return 'Enter a product name or product code.';
        String searchPattern = '%' + searchText.trim() + '%';
        List<Product__c> products = [
            SELECT Name, Product_Code__c, Unit_Price__c, Available_Quantity__c, Description__c
            FROM Product__c
            WHERE Active__c = true AND (Name LIKE :searchPattern OR Product_Code__c LIKE :searchPattern)
            WITH USER_MODE
            ORDER BY Name
            LIMIT 10
        ];
        if (products.isEmpty()) return 'No active products matched that search.';

        List<String> summaries = new List<String>();
        for (Product__c product : products) {
            String summary = product.Name + ' (' + product.Product_Code__c + '): price '
                + String.valueOf(product.Unit_Price__c) + '; '
                + String.valueOf(product.Available_Quantity__c) + ' available.';
            if (String.isNotBlank(product.Description__c)) summary += ' ' + product.Description__c;
            summaries.add(summary);
        }
        return String.join(summaries, '\n');
    }
}
