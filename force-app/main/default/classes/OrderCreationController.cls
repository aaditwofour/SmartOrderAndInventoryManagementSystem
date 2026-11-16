public with sharing class OrderCreationController {
    @AuraEnabled
    public static Id createOrder(Id customerId, List<OrderLineInput> lines) {
        if (!Schema.sObjectType.Customer__c.isAccessible()
            || !Schema.sObjectType.Product__c.isAccessible()
            || !Schema.sObjectType.Sales_Order__c.isCreateable()
            || !Schema.sObjectType.Sales_Order__c.fields.Customer__c.isCreateable()
            || !Schema.sObjectType.Sales_Order__c.fields.Order_Date__c.isCreateable()
            || !Schema.sObjectType.Sales_Order__c.fields.Order_Status__c.isCreateable()
            || !Schema.sObjectType.Order_Item__c.isCreateable()
            || !Schema.sObjectType.Order_Item__c.fields.Product__c.isCreateable()
            || !Schema.sObjectType.Order_Item__c.fields.Quantity__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create customer orders.');
        }
        if (customerId == null) throw new AuraHandledException('Select a customer.');
        if (lines == null || lines.isEmpty()) throw new AuraHandledException('Add at least one product.');

        Set<Id> productIds = new Set<Id>();
        for (OrderLineInput line : lines) {
            if (line == null || line.productId == null || line.quantity == null || line.quantity <= 0) {
                throw new AuraHandledException('Each order line needs a product and a quantity greater than zero.');
            }
            productIds.add(line.productId);
        }

        try {
            Customer__c customer = [SELECT Id FROM Customer__c WHERE Id=:customerId WITH USER_MODE LIMIT 1];
            Map<Id, Product__c> products = new Map<Id, Product__c>([
                SELECT Id, Name, Unit_Price__c, Active__c
                FROM Product__c WHERE Id IN :productIds WITH USER_MODE
            ]);
            if (products.size() != productIds.size()) throw new AuraHandledException('One or more products are unavailable.');
            for (Product__c product : products.values()) {
                if (product.Active__c != true) throw new AuraHandledException(product.Name + ' is inactive.');
            }

            Sales_Order__c orderRecord = new Sales_Order__c(
                Customer__c=customer.Id,
                Order_Date__c=Date.today(),
                Order_Status__c='Draft'
            );
            insert as user orderRecord;

            List<Order_Item__c> orderItems = new List<Order_Item__c>();
            for (OrderLineInput line : lines) {
                orderItems.add(new Order_Item__c(
                    Sales_Order__c=orderRecord.Id,
                    Product__c=line.productId,
                    Quantity__c=line.quantity
                ));
            }
            insert as user orderItems;

            orderRecord.Order_Status__c='Submitted';
            update as user orderRecord;
            return orderRecord.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Order could not be created: ' + e.getMessage());
        }
    }
}
