@IsTest
private class OrderCreationFlowActionTest {
    private static Product__c makeProduct(String name, Decimal price, Decimal quantity, Boolean active) {
        Product__c product = new Product__c(
            Name=name,
            Product_Code__c=name.left(3).toUpperCase(),
            Unit_Price__c=price,
            Available_Quantity__c=quantity,
            Reorder_Level__c=1,
            Active__c=active
        );
        insert product;
        return product;
    }

    private static OrderCreationFlowAction.Request makeRequest(Id customerId, Id productId, Decimal quantity) {
        OrderCreationFlowAction.Request request = new OrderCreationFlowAction.Request();
        request.customerId=customerId;
        request.productId=productId;
        request.quantity=quantity;
        return request;
    }

    @IsTest static void createsOrdersInBulkAndReturnsIds() {
        Customer__c customer = new Customer__c(Name='Flow Customer');
        insert customer;
        Product__c product = makeProduct('Flow Monitor', 1000, 10, true);
        List<OrderCreationFlowAction.Request> requests = new List<OrderCreationFlowAction.Request>{
            makeRequest(customer.Id, product.Id, 2),
            makeRequest(customer.Id, product.Id, 3)
        };

        Test.startTest();
        List<OrderCreationFlowAction.Result> results = OrderCreationFlowAction.createOrders(requests);
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertNotEquals(null, results[0].orderId);
        System.assertNotEquals(null, results[1].orderId);
        List<Sales_Order__c> createdOrders = [
            SELECT Order_Status__c, Inventory_Processed__c, Order_Total__c
            FROM Sales_Order__c WHERE Id IN :new Set<Id>{results[0].orderId, results[1].orderId}
        ];
        System.assertEquals(2, createdOrders.size());
        Decimal totalAmount = 0;
        for (Sales_Order__c orderRecord : createdOrders) {
            System.assertEquals('Processing', orderRecord.Order_Status__c);
            System.assertEquals(true, orderRecord.Inventory_Processed__c);
            totalAmount += orderRecord.Order_Total__c;
        }
        System.assertEquals(5000, totalAmount);
        Product__c updatedProduct = [SELECT Available_Quantity__c FROM Product__c WHERE Id=:product.Id];
        System.assertEquals(5, updatedProduct.Available_Quantity__c);
    }

    @IsTest static void rejectsInactiveProducts() {
        Customer__c customer = new Customer__c(Name='Inactive Flow Customer');
        insert customer;
        Product__c product = makeProduct('Inactive Item', 50, 2, false);

        try {
            OrderCreationFlowAction.createOrders(new List<OrderCreationFlowAction.Request>{
                makeRequest(customer.Id, product.Id, 1)
            });
            System.assert(false, 'Inactive products must not be ordered.');
        } catch (OrderCreationFlowAction.FlowActionException expected) {
            System.assert(expected.getMessage().contains('inactive'));
        }
    }
}
