public with sharing class OrderItemHandler {
    public static void beforeSave(List<Order_Item__c> records, Map<Id, Order_Item__c> oldMap) {
        Set<Id> orderIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        for (Order_Item__c item : records) {
            if (item.Sales_Order__c != null) orderIds.add(item.Sales_Order__c);
            if (item.Product__c != null) productIds.add(item.Product__c);
            if (item.Quantity__c == null || item.Quantity__c <= 0) item.addError('Quantity must be greater than zero.');
        }

        Map<Id, Sales_Order__c> orders = new Map<Id, Sales_Order__c>([
            SELECT Id, Order_Status__c FROM Sales_Order__c WHERE Id IN :orderIds
        ]);
        for (Order_Item__c item : records) {
            Sales_Order__c parentOrder = orders.get(item.Sales_Order__c);
            if (parentOrder == null || parentOrder.Order_Status__c != 'Draft') {
                item.addError('Order items can only be added or changed while the order is Draft.');
            }
        }

        Map<Id, Product__c> products = new Map<Id, Product__c>([
            SELECT Id, Unit_Price__c, Active__c FROM Product__c WHERE Id IN :productIds
        ]);
        for (Order_Item__c item : records) {
            Product__c product = products.get(item.Product__c);
            if (product == null) {
                item.addError('Select a product.');
                continue;
            }
            if (product.Active__c != true) item.addError('Inactive products cannot be ordered.');

            Boolean productChanged = oldMap != null && oldMap.containsKey(item.Id)
                && oldMap.get(item.Id).Product__c != item.Product__c;
            if (item.Unit_Price__c == null || productChanged) item.Unit_Price__c = product.Unit_Price__c;
            if (item.Unit_Price__c == null || item.Unit_Price__c < 0) {
                item.addError('A valid unit price is required.');
            }
        }
    }
}
