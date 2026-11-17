@IsTest
private class AgentforceProductLookupActionTest {
    @TestSetup
    static void createProducts() {
        insert new Product__c(
            Name = 'Agentforce Test Keyboard',
            Product_Code__c = 'AF-KEY-001',
            Unit_Price__c = 1250,
            Available_Quantity__c = 8,
            Reorder_Level__c = 2,
            Active__c = true,
            Description__c = 'Mechanical keyboard for lookup testing'
        );
    }

    @IsTest
    static void returnsLiveProductDetails() {
        AgentforceProductLookupAction.Request request =
            new AgentforceProductLookupAction.Request();
        request.searchText = 'AF-KEY-001';

        Test.startTest();
        List<AgentforceProductLookupAction.Response> responses =
            AgentforceProductLookupAction.findProducts(
                new List<AgentforceProductLookupAction.Request>{ request }
            );
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isTrue(responses[0].resultText.contains('Agentforce Test Keyboard'));
        Assert.isTrue(responses[0].resultText.contains('1250'));
        Assert.isTrue(responses[0].resultText.contains('8 available'));
        Assert.isTrue(responses[0].resultText.contains('Mechanical keyboard'));
    }

    @IsTest
    static void handlesEmptyAndUnmatchedSearches() {
        List<AgentforceProductLookupAction.Request> requests =
            new List<AgentforceProductLookupAction.Request>();
        AgentforceProductLookupAction.Request emptyRequest =
            new AgentforceProductLookupAction.Request();
        emptyRequest.searchText = ' ';
        requests.add(emptyRequest);

        AgentforceProductLookupAction.Request unmatchedRequest =
            new AgentforceProductLookupAction.Request();
        unmatchedRequest.searchText = 'not-a-product';
        requests.add(unmatchedRequest);

        List<AgentforceProductLookupAction.Response> responses =
            AgentforceProductLookupAction.findProducts(requests);

        Assert.areEqual(2, responses.size());
        Assert.isTrue(responses[0].resultText.contains('Enter a product name'));
        Assert.isTrue(responses[1].resultText.contains('No active products matched'));
        Assert.areEqual(0, AgentforceProductLookupAction.findProducts(null).size());
    }
}
