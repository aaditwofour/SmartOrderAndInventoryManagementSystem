trigger OrderItemTrigger on Order_Item__c (before insert, before update) {
    if (Trigger.isBefore) OrderItemHandler.beforeSave(Trigger.new, Trigger.isUpdate ? Trigger.oldMap : null);
}
