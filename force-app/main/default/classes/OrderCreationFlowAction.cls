public with sharing class OrderCreationFlowAction {
    public class Request {
        @InvocableVariable(required=true label='Customer')
        public Id customerId;

        @InvocableVariable(required=true label='Product')
        public Id productId;

        @InvocableVariable(required=true label='Quantity')
        public Decimal quantity;
    }

    public class Result {
        @InvocableVariable(label='Created Order ID')
        public Id orderId;
    }

    @InvocableMethod(
        label='Create Customer Order'
        description='Creates and submits one customer order for a product and quantity. Inventory and approval rules run automatically.'
    )
    public static List<Result> createOrders(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) return results;

        if (!Schema.sObjectType.Customer__c.isAccessible()
            || !Schema.sObjectType.Product__c.isAccessible()
            || !Schema.sObjectType.Product__c.fields.Unit_Price__c.isAccessible()
            || !Schema.sObjectType.Product__c.fields.Active__c.isAccessible()
            || !Schema.sObjectType.Sales_Order__c.isCreateable()
            || !Schema.sObjectType.Sales_Order__c.fields.Customer__c.isCreateable()
            || !Schema.sObjectType.Sales_Order__c.fields.Order_Date__c.isCreateable()
            || !Schema.sObjectType.Sales_Order__c.fields.Order_Status__c.isCreateable()
            || !Schema.sObjectType.Order_Item__c.isCreateable()
            || !Schema.sObjectType.Order_Item__c.fields.Sales_Order__c.isCreateable()
            || !Schema.sObjectType.Order_Item__c.fields.Product__c.isCreateable()
            || !Schema.sObjectType.Order_Item__c.fields.Quantity__c.isCreateable()) {
            throw new FlowActionException('You do not have permission to create customer orders.');
        }

        Set<Id> customerIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();
        for (Request request : requests) {
            if (request == null || request.customerId == null || request.productId == null
                || request.quantity == null || request.quantity <= 0) {
                throw new FlowActionException('Each order needs a customer, a product, and a quantity greater than zero.');
            }
            customerIds.add(request.customerId);
            productIds.add(request.productId);
        }

        Map<Id, Customer__c> customersById = new Map<Id, Customer__c>([
            SELECT Id FROM Customer__c WHERE Id IN :customerIds WITH USER_MODE
        ]);
        Map<Id, Product__c> productsById = new Map<Id, Product__c>([
            SELECT Id, Name, Active__c FROM Product__c WHERE Id IN :productIds WITH USER_MODE
        ]);

        List<Sales_Order__c> orders = new List<Sales_Order__c>();
        for (Request request : requests) {
            if (!customersById.containsKey(request.customerId)) {
                throw new FlowActionException('A selected customer is unavailable.');
            }
            Product__c product = productsById.get(request.productId);
            if (product == null) throw new FlowActionException('A selected product is unavailable.');
            if (product.Active__c != true) throw new FlowActionException(product.Name + ' is inactive.');
            orders.add(new Sales_Order__c(
                Customer__c=request.customerId,
                Order_Date__c=Date.today(),
                Order_Status__c='Draft'
            ));
        }

        insert as user orders;

        List<Order_Item__c> items = new List<Order_Item__c>();
        for (Integer i = 0; i < requests.size(); i++) {
            Request request = requests[i];
            items.add(new Order_Item__c(
                Sales_Order__c=orders[i].Id,
                Product__c=request.productId,
                Quantity__c=request.quantity
            ));
        }
        insert as user items;

        for (Sales_Order__c orderRecord : orders) orderRecord.Order_Status__c='Submitted';
        update as user orders;

        for (Sales_Order__c orderRecord : orders) {
            Result result = new Result();
            result.orderId = orderRecord.Id;
            results.add(result);
        }
        return results;
    }

    public class FlowActionException extends Exception {}
}
