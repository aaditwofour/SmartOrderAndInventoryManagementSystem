@IsTest
private class OrderSyncQueueableTest {
    private class SuccessfulSyncMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('POST', request.getMethod());
            System.assertEquals('callout:OrderSyncMock/orders', request.getEndpoint());
            System.assert(!String.isBlank(request.getHeader('Idempotency-Key')));
            System.assert(request.getBody().contains('salesforceOrderId'));
            HttpResponse response = new HttpResponse();
            response.setStatusCode(201);
            response.setBody('{"externalOrderId":"EXT-100","externalInvoiceId":"INV-100"}');
            return response;
        }
    }

    private class FailedSyncMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(503);
            response.setBody('{"message":"service unavailable"}');
            return response;
        }
    }

    private static Sales_Order__c makeOrder() {
        Customer__c customer = new Customer__c(Name='Integration Test Customer');
        insert customer;
        Product__c product = new Product__c(
            Name='Integration Test Product', Product_Code__c='ITP-1',
            Unit_Price__c=250, Available_Quantity__c=10, Reorder_Level__c=1, Active__c=true
        );
        insert product;
        Sales_Order__c orderRecord = new Sales_Order__c(
            Customer__c=customer.Id, Order_Date__c=Date.today(),
            Order_Status__c='Draft'
        );
        insert orderRecord;
        insert new Order_Item__c(Sales_Order__c=orderRecord.Id, Product__c=product.Id, Quantity__c=2);
        return orderRecord;
    }

    private static void markInventoryProcessed(Sales_Order__c orderRecord) {
        orderRecord.Order_Status__c='Processing';
        orderRecord.Inventory_Processed__c=true;
        update orderRecord;
    }

    @IsTest static void successfulResponseStoresReferenceAndInvoice() {
        Sales_Order__c orderRecord = makeOrder();
        Test.setMock(HttpCalloutMock.class, new SuccessfulSyncMock());

        Test.startTest();
        OrderSyncDispatcher.enabledForTest=true;
        OrderSyncDispatcher.namedCredentialForTest='OrderSyncMock';
        markInventoryProcessed(orderRecord);
        Test.stopTest();

        Sales_Order__c synced = [SELECT Sync_Status__c, External_Order_ID__c, Sync_Error__c FROM Sales_Order__c WHERE Id=:orderRecord.Id];
        System.assertEquals('Synced', synced.Sync_Status__c);
        System.assertEquals('EXT-100', synced.External_Order_ID__c);
        System.assertEquals(null, synced.Sync_Error__c);
        Invoice__c invoiceRecord = [SELECT External_Invoice_ID__c, Invoice_Amount__c, Sync_Status__c FROM Invoice__c WHERE Sales_Order__c=:orderRecord.Id];
        System.assertEquals('INV-100', invoiceRecord.External_Invoice_ID__c);
        System.assertEquals(500, invoiceRecord.Invoice_Amount__c);
        System.assertEquals('Synced', invoiceRecord.Sync_Status__c);
    }

    @IsTest static void unsuccessfulResponseDoesNotMarkOrderSynced() {
        Sales_Order__c orderRecord = makeOrder();
        Test.setMock(HttpCalloutMock.class, new FailedSyncMock());

        Test.startTest();
        OrderSyncDispatcher.enabledForTest=true;
        OrderSyncDispatcher.namedCredentialForTest='OrderSyncMock';
        markInventoryProcessed(orderRecord);
        Test.stopTest();

        Sales_Order__c failed = [SELECT Sync_Status__c, External_Order_ID__c, Sync_Error__c FROM Sales_Order__c WHERE Id=:orderRecord.Id];
        System.assertEquals('Failed', failed.Sync_Status__c);
        System.assertEquals(null, failed.External_Order_ID__c);
        System.assert(failed.Sync_Error__c.contains('503'));
        System.assertEquals(0, [SELECT count() FROM Invoice__c WHERE Sales_Order__c=:orderRecord.Id]);
    }

    @IsTest static void disabledIntegrationLeavesOrderUnsent() {
        Sales_Order__c orderRecord = makeOrder();
        Test.startTest();
        OrderSyncDispatcher.enabledForTest=false;
        markInventoryProcessed(orderRecord);
        Test.stopTest();

        Sales_Order__c unchanged = [SELECT Sync_Status__c FROM Sales_Order__c WHERE Id=:orderRecord.Id];
        System.assertEquals('Not Synced', unchanged.Sync_Status__c);
    }

    @IsTest static void invalidNamedCredentialIsRejected() {
        Sales_Order__c orderRecord = makeOrder();
        Test.startTest();
        OrderSyncDispatcher.enabledForTest=true;
        OrderSyncDispatcher.namedCredentialForTest='not-valid';
        try {
            OrderSyncDispatcher.enqueueIfEnabled(new Set<Id>{orderRecord.Id});
            System.assert(false, 'Expected an invalid credential name to be rejected.');
        } catch (OrderSyncDispatcher.OrderSyncConfigurationException expected) {
            System.assert(expected.getMessage().contains('invalid'));
        }
        Test.stopTest();
    }
}
