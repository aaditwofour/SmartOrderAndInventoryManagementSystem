public with sharing class StoreOperationsAssistantController {
    @AuraEnabled
    public static String lookupProducts(String searchText) {
        OrderAssistantLookupAction.Request request = new OrderAssistantLookupAction.Request();
        request.lookupType = 'CHECK_STOCK';
        request.lookupValue = searchText;

        List<OrderAssistantLookupAction.Response> results = OrderAssistantLookupAction.execute(
            new List<OrderAssistantLookupAction.Request>{ request }
        );
        return results.isEmpty() ? 'No product details were returned.' : results[0].resultText;
    }
}
