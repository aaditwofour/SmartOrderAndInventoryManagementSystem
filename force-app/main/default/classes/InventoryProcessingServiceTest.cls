@IsTest
private class InventoryProcessingServiceTest {
    private static Product__c makeProduct(String name, Decimal price, Decimal stock) {
        Product__c product = new Product__c(
            Name=name,
            Product_Code__c=name.left(3).toUpperCase(),
            Unit_Price__c=price,
            Available_Quantity__c=stock,
            Reorder_Level__c=1,
            Active__c=true
        );
        insert product;
        return product;
    }

    private static Sales_Order__c makeOrder(Product__c product, Decimal quantity) {
        Customer__c customer = new Customer__c(Name='Test Customer');
        insert customer;
        Sales_Order__c orderRecord = new Sales_Order__c(
            Customer__c=customer.Id,
            Order_Date__c=Date.today(),
            Order_Status__c='Draft'
        );
        insert orderRecord;
        insert new Order_Item__c(
            Sales_Order__c=orderRecord.Id,
            Product__c=product.Id,
            Quantity__c=quantity
        );
        return orderRecord;
    }

    @IsTest static void lowValueOrderSnapshotsPriceAndDeductsStockOnce() {
        Product__c product = makeProduct('Mouse', 800, 10);
        Sales_Order__c orderRecord = makeOrder(product, 2);
        Order_Item__c item = [SELECT Unit_Price__c, Line_Total__c FROM Order_Item__c WHERE Sales_Order__c=:orderRecord.Id];
        System.assertEquals(800, item.Unit_Price__c, 'Unit price is captured from the product.');
        System.assertEquals(1600, item.Line_Total__c);
        product.Unit_Price__c=999;
        update product;
        item = [SELECT Unit_Price__c, Line_Total__c FROM Order_Item__c WHERE Sales_Order__c=:orderRecord.Id];
        System.assertEquals(800, item.Unit_Price__c, 'A later product price change must not change the order snapshot.');
        System.assertEquals(1600, item.Line_Total__c);

        Test.startTest();
        orderRecord.Order_Status__c='Submitted';
        update orderRecord;
        Test.stopTest();

        Sales_Order__c processed = [SELECT Order_Status__c, Approval_Status__c, Inventory_Processed__c FROM Sales_Order__c WHERE Id=:orderRecord.Id];
        Product__c updatedProduct = [SELECT Available_Quantity__c FROM Product__c WHERE Id=:product.Id];
        System.assertEquals('Processing', processed.Order_Status__c);
        System.assertEquals(true, processed.Inventory_Processed__c);
        System.assertEquals(8, updatedProduct.Available_Quantity__c);

        update processed;
        updatedProduct = [SELECT Available_Quantity__c FROM Product__c WHERE Id=:product.Id];
        System.assertEquals(8, updatedProduct.Available_Quantity__c, 'A second update must not deduct stock again.');
    }

    @IsTest static void highValueOrderWaitsForApproval() {
        Product__c product = makeProduct('Laptop', 55000, 10);
        Sales_Order__c orderRecord = makeOrder(product, 2);
        orderRecord.Order_Status__c='Submitted';
        update orderRecord;

        Sales_Order__c pending = [SELECT Order_Status__c, Approval_Status__c, Inventory_Processed__c FROM Sales_Order__c WHERE Id=:orderRecord.Id];
        System.assertEquals('Submitted', pending.Order_Status__c);
        System.assertEquals('Pending', pending.Approval_Status__c);
        System.assertEquals(false, pending.Inventory_Processed__c);
        pending.Approval_Status__c='Approved';
        update pending;
        pending = [SELECT Order_Status__c, Inventory_Processed__c FROM Sales_Order__c WHERE Id=:orderRecord.Id];
        System.assertEquals('Processing', pending.Order_Status__c);
        System.assertEquals(true, pending.Inventory_Processed__c);
        Product__c updatedProduct = [SELECT Available_Quantity__c FROM Product__c WHERE Id=:product.Id];
        System.assertEquals(8, updatedProduct.Available_Quantity__c);
    }

    @IsTest static void insufficientStockRejectsWithoutDeduction() {
        Product__c product = makeProduct('Keyboard', 1500, 3);
        Sales_Order__c orderRecord = makeOrder(product, 4);
        orderRecord.Order_Status__c='Submitted';
        update orderRecord;

        Sales_Order__c rejected = [SELECT Order_Status__c, Approval_Status__c, Inventory_Processed__c FROM Sales_Order__c WHERE Id=:orderRecord.Id];
        Product__c unchanged = [SELECT Available_Quantity__c FROM Product__c WHERE Id=:product.Id];
        System.assertEquals('Rejected', rejected.Order_Status__c);
        System.assertEquals(false, rejected.Inventory_Processed__c);
        System.assertEquals(3, unchanged.Available_Quantity__c);
    }

    @IsTest static void orderCreatorCreatesAndSubmitsAnOrder() {
        Product__c product = makeProduct('Monitor', 12000, 5);
        Customer__c customer = new Customer__c(Name='Order Creator Customer');
        insert customer;
        OrderLineInput line = new OrderLineInput();
        line.productId=product.Id;
        line.quantity=2;

        Test.startTest();
        Id orderId = OrderCreationController.createOrder(customer.Id, new List<OrderLineInput>{line});
        Test.stopTest();

        Sales_Order__c orderRecord = [SELECT Order_Status__c, Inventory_Processed__c, Order_Total__c FROM Sales_Order__c WHERE Id=:orderId];
        Order_Item__c createdItem = [SELECT Unit_Price__c, Quantity__c FROM Order_Item__c WHERE Sales_Order__c=:orderId];
        Product__c updatedProduct = [SELECT Available_Quantity__c FROM Product__c WHERE Id=:product.Id];
        System.assertEquals('Processing', orderRecord.Order_Status__c);
        System.assertEquals(true, orderRecord.Inventory_Processed__c);
        System.assertEquals(24000, orderRecord.Order_Total__c);
        System.assertEquals(12000, createdItem.Unit_Price__c);
        System.assertEquals(3, updatedProduct.Available_Quantity__c);
    }
}
