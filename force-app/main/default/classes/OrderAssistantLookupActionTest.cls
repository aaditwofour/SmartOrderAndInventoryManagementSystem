@IsTest
private class OrderAssistantLookupActionTest {
    @IsTest static void executesReadOnlyLookupTypes() {
        Product__c product = new Product__c(
            Name='Assistant Lookup Laptop', Product_Code__c='ASST-LAP',
            Unit_Price__c=400, Available_Quantity__c=3, Reorder_Level__c=5, Active__c=true
        );
        insert product;
        Customer__c customer = new Customer__c(Name='Assistant Lookup Customer', Email__c='assistant@example.test');
        insert customer;
        Sales_Order__c orderRecord = new Sales_Order__c(
            Customer__c=customer.Id, Order_Date__c=Date.today(),
            Order_Status__c='Draft'
        );
        insert orderRecord;
        Product__c approvalProduct = new Product__c(
            Name='Assistant Approval Product', Product_Code__c='ASST-APR',
            Unit_Price__c=60000, Available_Quantity__c=10, Reorder_Level__c=1, Active__c=true
        );
        insert approvalProduct;
        insert new Order_Item__c(Sales_Order__c=orderRecord.Id, Product__c=approvalProduct.Id, Quantity__c=2);
        orderRecord.Order_Status__c='Submitted';
        update orderRecord;
        orderRecord = [SELECT Id, Name FROM Sales_Order__c WHERE Id=:orderRecord.Id];
        Invoice__c invoiceRecord = new Invoice__c(
            Sales_Order__c=orderRecord.Id, External_Invoice_ID__c='EXT-INV-ASYNC-1',
            Sync_Status__c='Synced', Invoice_Amount__c=800, Invoice_Date__c=Date.today()
        );
        insert invoiceRecord;

        List<OrderAssistantLookupAction.Request> requests = new List<OrderAssistantLookupAction.Request>();
        for (String lookupType : new List<String>{'CHECK_STOCK', 'PENDING_APPROVALS', 'ORDER_DETAILS', 'INVOICE_STATUS'}) {
            OrderAssistantLookupAction.Request request = new OrderAssistantLookupAction.Request();
            request.lookupType=lookupType;
            request.lookupValue=lookupType == 'CHECK_STOCK' ? 'ASST-LAP'
                : lookupType == 'ORDER_DETAILS' ? orderRecord.Name
                : lookupType == 'INVOICE_STATUS' ? 'EXT-INV-ASYNC-1' : null;
            requests.add(request);
        }

        Test.startTest();
        List<OrderAssistantLookupAction.Response> results=OrderAssistantLookupAction.execute(requests);
        Test.stopTest();

        System.assertEquals(4, results.size());
        System.assert(results[0].resultText.contains('3 available'));
        System.assert(results[1].resultText.contains(orderRecord.Name));
        System.assert(results[2].resultText.contains('Submitted'));
        System.assert(results[3].resultText.contains('EXT-INV-ASYNC-1'));

        OrderAssistantLookupAction.Request authorized = new OrderAssistantLookupAction.Request();
        authorized.lookupType='ORDER_DETAILS';
        authorized.lookupValue=orderRecord.Name;
        authorized.customerEmail='assistant@example.test';
        OrderAssistantLookupAction.Request unauthorized = new OrderAssistantLookupAction.Request();
        unauthorized.lookupType='ORDER_DETAILS';
        unauthorized.lookupValue=orderRecord.Name;
        unauthorized.customerEmail='other@example.test';
        List<OrderAssistantLookupAction.Response> customerResults = OrderAssistantLookupAction.execute(
            new List<OrderAssistantLookupAction.Request>{authorized, unauthorized}
        );
        System.assert(customerResults[0].resultText.contains('Submitted'));
        System.assert(customerResults[1].resultText.contains('No matching order'));
    }

    @IsTest static void asksForMissingAndValidLookupType() {
        OrderAssistantLookupAction.Request missingType = new OrderAssistantLookupAction.Request();
        OrderAssistantLookupAction.Request unsupportedType = new OrderAssistantLookupAction.Request();
        unsupportedType.lookupType='DELETE_RECORD';

        List<OrderAssistantLookupAction.Response> results = OrderAssistantLookupAction.execute(
            new List<OrderAssistantLookupAction.Request>{missingType, unsupportedType}
        );

        System.assert(results[0].resultText.contains('Choose a lookup type'));
        System.assert(results[1].resultText.contains('Unsupported lookup type'));
    }
}
