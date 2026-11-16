public with sharing class OrderInventoryDashboardController {
    public class ProductSummary {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String productCode { get; set; }
        @AuraEnabled public Decimal availableQuantity { get; set; }
        @AuraEnabled public Decimal reorderLevel { get; set; }

        public ProductSummary(Product__c product) {
            id = product.Id;
            name = product.Name;
            productCode = product.Product_Code__c;
            availableQuantity = product.Available_Quantity__c;
            reorderLevel = product.Reorder_Level__c;
        }
    }

    public class OrderStatusSummary {
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Integer orderCount { get; set; }
        @AuraEnabled public Decimal orderTotal { get; set; }

        public OrderStatusSummary(String status, Integer orderCount, Decimal orderTotal) {
            this.status = status;
            this.orderCount = orderCount;
            this.orderTotal = orderTotal;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductSummary> getLowStockProducts() {
        List<ProductSummary> results = new List<ProductSummary>();
        for (Product__c product : [
            SELECT Id, Name, Product_Code__c, Available_Quantity__c, Reorder_Level__c
            FROM Product__c
            WHERE Active__c = true AND Low_Stock__c = true
            WITH USER_MODE
            ORDER BY Available_Quantity__c ASC
            LIMIT 10
        ]) {
            results.add(new ProductSummary(product));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<OrderStatusSummary> getOrderStatusSummary() {
        List<OrderStatusSummary> results = new List<OrderStatusSummary>();
        for (AggregateResult groupedOrder : [
            SELECT Order_Status__c status, COUNT(Id) orderCount, SUM(Order_Total__c) orderTotal
            FROM Sales_Order__c
            WITH USER_MODE
            GROUP BY Order_Status__c
            ORDER BY Order_Status__c
        ]) {
            results.add(new OrderStatusSummary(
                (String)groupedOrder.get('status'),
                (Integer)groupedOrder.get('orderCount'),
                (Decimal)groupedOrder.get('orderTotal')
            ));
        }
        return results;
    }
}
