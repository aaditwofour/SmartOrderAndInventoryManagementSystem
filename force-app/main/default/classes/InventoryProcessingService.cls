public with sharing class InventoryProcessingService {
    public static void processApprovedOrders(Set<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) return;

        List<Sales_Order__c> orders = [
            SELECT Id, Order_Status__c, Approval_Status__c, Inventory_Processed__c
            FROM Sales_Order__c
            WHERE Id IN :orderIds AND Order_Status__c = 'Approved' AND Inventory_Processed__c = false
            FOR UPDATE
        ];
        if (orders.isEmpty()) return;

        Set<Id> eligibleOrderIds = new Map<Id, Sales_Order__c>(orders).keySet();
        List<Order_Item__c> items = [
            SELECT Id, Sales_Order__c, Product__c, Quantity__c
            FROM Order_Item__c WHERE Sales_Order__c IN :eligibleOrderIds
            ORDER BY Sales_Order__c, Product__c, Id
        ];

        Map<Id, Map<Id, Decimal>> quantityByOrderAndProduct = new Map<Id, Map<Id, Decimal>>();
        Set<Id> productIds = new Set<Id>();
        for (Order_Item__c item : items) {
            if (!quantityByOrderAndProduct.containsKey(item.Sales_Order__c)) {
                quantityByOrderAndProduct.put(item.Sales_Order__c, new Map<Id, Decimal>());
            }
            Map<Id, Decimal> orderQuantities = quantityByOrderAndProduct.get(item.Sales_Order__c);
            orderQuantities.put(item.Product__c, (orderQuantities.containsKey(item.Product__c) ? orderQuantities.get(item.Product__c) : 0) + item.Quantity__c);
            productIds.add(item.Product__c);
        }

        List<Product__c> lockedProducts = [
            SELECT Id, Available_Quantity__c, Active__c
            FROM Product__c WHERE Id IN :productIds FOR UPDATE
        ];
        Map<Id, Product__c> products = new Map<Id, Product__c>(lockedProducts);
        Map<Id, Decimal> remainingStock = new Map<Id, Decimal>();
        for (Product__c product : lockedProducts) remainingStock.put(product.Id, product.Available_Quantity__c == null ? 0 : product.Available_Quantity__c);

        List<Sales_Order__c> ordersToUpdate = new List<Sales_Order__c>();
        Set<Id> processedProductIds = new Set<Id>();
        for (Sales_Order__c orderRecord : orders) {
            Map<Id, Decimal> required = quantityByOrderAndProduct.get(orderRecord.Id);
            Boolean hasItems = required != null && !required.isEmpty();
            Boolean sufficient = hasItems;
            if (hasItems) {
                for (Id productId : required.keySet()) {
                    Product__c product = products.get(productId);
                    if (product == null || product.Active__c != true || remainingStock.get(productId) < required.get(productId)) {
                        sufficient = false;
                        break;
                    }
                }
            }

            if (!sufficient) {
                orderRecord.Order_Status__c = 'Rejected';
                orderRecord.Approval_Status__c = 'Rejected';
                ordersToUpdate.add(orderRecord);
                continue;
            }

            for (Id productId : required.keySet()) {
                remainingStock.put(productId, remainingStock.get(productId) - required.get(productId));
                processedProductIds.add(productId);
            }
            orderRecord.Inventory_Processed__c = true;
            orderRecord.Order_Status__c = 'Processing';
            ordersToUpdate.add(orderRecord);
        }

        List<Product__c> productsToUpdate = new List<Product__c>();
        for (Id productId : processedProductIds) {
            Product__c product = products.get(productId);
            product.Available_Quantity__c = remainingStock.get(productId);
            productsToUpdate.add(product);
        }
        if (!productsToUpdate.isEmpty()) update productsToUpdate;
        if (!ordersToUpdate.isEmpty()) update ordersToUpdate;
    }
}
