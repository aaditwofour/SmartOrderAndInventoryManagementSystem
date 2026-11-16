public with sharing class SalesOrderAutomationHandler {
    @TestVisible private static final Decimal HIGH_VALUE_THRESHOLD = 100000;

    public static void beforeUpdate(List<Sales_Order__c> records, Map<Id, Sales_Order__c> oldMap) {
        for (Sales_Order__c orderRecord : records) {
            Sales_Order__c prior = oldMap.get(orderRecord.Id);
            if (orderRecord.Order_Status__c == 'Submitted' && prior.Order_Status__c == 'Draft') {
                if (orderRecord.Order_Total__c == null || orderRecord.Order_Total__c <= 0) {
                    orderRecord.addError('Add at least one order item with a positive total before submitting.');
                    continue;
                }
                if (orderRecord.Order_Total__c >= HIGH_VALUE_THRESHOLD) {
                    orderRecord.Approval_Status__c = 'Pending';
                } else {
                    orderRecord.Approval_Status__c = 'Not Required';
                    orderRecord.Order_Status__c = 'Approved';
                }
            }

            if (orderRecord.Approval_Status__c != prior.Approval_Status__c) {
                if (orderRecord.Approval_Status__c == 'Approved') orderRecord.Order_Status__c = 'Approved';
                if (orderRecord.Approval_Status__c == 'Rejected') orderRecord.Order_Status__c = 'Rejected';
            }

            if (orderRecord.Order_Status__c == 'Approved'
                && orderRecord.Order_Total__c >= HIGH_VALUE_THRESHOLD
                && orderRecord.Approval_Status__c != 'Approved') {
                orderRecord.addError('High-value orders require manager approval before processing.');
            }
            if (prior.Inventory_Processed__c == true && orderRecord.Inventory_Processed__c != true) {
                orderRecord.addError('Processed inventory cannot be reset.');
            }
            if (prior.Inventory_Processed__c == true && orderRecord.Order_Status__c != prior.Order_Status__c) {
                orderRecord.addError('The status of an order cannot be changed after inventory is processed.');
            }
        }
    }

    public static void afterUpdate(List<Sales_Order__c> records, Map<Id, Sales_Order__c> oldMap) {
        Set<Id> approvedOrderIds = new Set<Id>();
        Set<Id> newlyProcessedOrderIds = new Set<Id>();
        for (Sales_Order__c orderRecord : records) {
            Sales_Order__c prior = oldMap.get(orderRecord.Id);
            if (orderRecord.Order_Status__c == 'Approved' && orderRecord.Inventory_Processed__c != true) {
                approvedOrderIds.add(orderRecord.Id);
            }
            if (orderRecord.Order_Status__c == 'Processing'
                && orderRecord.Inventory_Processed__c == true
                && (prior == null || prior.Inventory_Processed__c != true)
                && orderRecord.Sync_Status__c == 'Not Synced') {
                newlyProcessedOrderIds.add(orderRecord.Id);
            }
        }
        if (!approvedOrderIds.isEmpty()) InventoryProcessingService.processApprovedOrders(approvedOrderIds);
        if (!newlyProcessedOrderIds.isEmpty()) OrderSyncDispatcher.enqueueIfEnabled(newlyProcessedOrderIds);
    }
}
