@IsTest
private class OrderInventoryDashboardControllerTest {
    @IsTest static void dashboardReturnsLowStockAndGroupedOrders() {
        Product__c lowStock = new Product__c(
            Name='Low Stock Dashboard Product', Product_Code__c='LSD-1',
            Unit_Price__c=100, Available_Quantity__c=2, Reorder_Level__c=5, Active__c=true
        );
        Product__c healthyStock = new Product__c(
            Name='Healthy Dashboard Product', Product_Code__c='HSD-1',
            Unit_Price__c=100, Available_Quantity__c=20, Reorder_Level__c=5, Active__c=true
        );
        insert new List<Product__c>{lowStock, healthyStock};

        Customer__c customer = new Customer__c(Name='Dashboard Test Customer');
        insert customer;
        Product__c orderProduct = new Product__c(
            Name='Dashboard Order Product', Product_Code__c='DOP-1',
            Unit_Price__c=250, Available_Quantity__c=5, Reorder_Level__c=1, Active__c=true
        );
        insert orderProduct;
        Sales_Order__c orderRecord = new Sales_Order__c(
            Customer__c=customer.Id,
            Order_Date__c=Date.today(),
            Order_Status__c='Draft'
        );
        insert orderRecord;
        insert new Order_Item__c(Sales_Order__c=orderRecord.Id, Product__c=orderProduct.Id, Quantity__c=1);

        Test.startTest();
        List<OrderInventoryDashboardController.ProductSummary> lowStockResults =
            OrderInventoryDashboardController.getLowStockProducts();
        List<OrderInventoryDashboardController.OrderStatusSummary> orderResults =
            OrderInventoryDashboardController.getOrderStatusSummary();
        Test.stopTest();

        System.assertEquals(1, lowStockResults.size());
        System.assertEquals('Low Stock Dashboard Product', lowStockResults[0].name);
        System.assertEquals(1, orderResults.size());
        System.assertEquals('Draft', orderResults[0].status);
        System.assertEquals(1, orderResults[0].orderCount);
        System.assertEquals(250, orderResults[0].orderTotal);
    }
}
