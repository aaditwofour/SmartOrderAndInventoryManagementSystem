trigger SalesOrderTrigger on Sales_Order__c (before update, after update) {
    if (Trigger.isBefore && Trigger.isUpdate) {
        SalesOrderAutomationHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        SalesOrderAutomationHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
