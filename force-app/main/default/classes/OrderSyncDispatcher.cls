public without sharing class OrderSyncDispatcher {
    @TestVisible private static Boolean enabledForTest;
    @TestVisible private static String namedCredentialForTest;

    public static void enqueueIfEnabled(Set<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) return;

        Order_Sync_Settings__mdt settings = Order_Sync_Settings__mdt.getInstance('Default');
        Boolean enabled = settings != null && settings.Enabled__c == true;
        String configuredCredential = settings == null ? null : settings.Named_Credential__c;
        if (Test.isRunningTest() && enabledForTest != null) {
            enabled = enabledForTest;
            configuredCredential = namedCredentialForTest;
        }
        if (!enabled || String.isBlank(configuredCredential)) return;

        String credentialName = configuredCredential.trim();
        if (!Pattern.matches('[A-Za-z][A-Za-z0-9_]*', credentialName)) {
            throw new OrderSyncConfigurationException('The configured Named Credential API name is invalid.');
        }

        List<Id> ids = new List<Id>();
        ids.addAll(orderIds);
        for (Integer offset = 0; offset < ids.size(); offset += 100) {
            List<Id> batchIds = new List<Id>();
            for (Integer i = offset; i < Math.min(offset + 100, ids.size()); i++) batchIds.add(ids[i]);

            List<Sales_Order__c> pendingOrders = [
                SELECT Id, Sync_Status__c
                FROM Sales_Order__c
                WHERE Id IN :batchIds
                    AND Order_Status__c = 'Processing'
                    AND Inventory_Processed__c = true
                    AND Sync_Status__c = 'Not Synced'
                FOR UPDATE
            ];
            if (pendingOrders.isEmpty()) continue;

            for (Sales_Order__c orderRecord : pendingOrders) orderRecord.Sync_Status__c = 'Pending';
            update pendingOrders;

            Set<Id> pendingIds = new Map<Id, Sales_Order__c>(pendingOrders).keySet();
            System.enqueueJob(new OrderSyncQueueable(pendingIds, credentialName));
        }
    }

    public class OrderSyncConfigurationException extends Exception {}
}
