public without sharing class OrderSyncQueueable implements Queueable, Database.AllowsCallouts {
    private Set<Id> orderIds;
    private String namedCredential;

    public OrderSyncQueueable(Set<Id> orderIds, String namedCredential) {
        this.orderIds = orderIds == null ? new Set<Id>() : orderIds.clone();
        this.namedCredential = namedCredential;
    }

    public void execute(QueueableContext context) {
        if (orderIds.isEmpty() || String.isBlank(namedCredential)) return;

        List<Sales_Order__c> orders = [
            SELECT Id, Name, Order_Date__c, Order_Total__c, External_Order_ID__c,
                Customer__r.Name, Sync_Status__c,
                (SELECT Id, Product__r.Name, Product__r.Product_Code__c, Quantity__c, Unit_Price__c
                 FROM Order_Items__r ORDER BY Id)
            FROM Sales_Order__c
            WHERE Id IN :orderIds AND Order_Status__c = 'Processing'
                AND Inventory_Processed__c = true AND Sync_Status__c = 'Pending'
        ];
        if (orders.isEmpty()) return;

        Http client = new Http();
        List<Sales_Order__c> ordersToUpdate = new List<Sales_Order__c>();
        List<Invoice__c> invoicesToInsert = new List<Invoice__c>();

        for (Sales_Order__c orderRecord : orders) {
            try {
                Map<String, Object> payload = new Map<String, Object>{
                    'orderNumber' => orderRecord.Name,
                    'salesforceOrderId' => String.valueOf(orderRecord.Id),
                    'orderDate' => orderRecord.Order_Date__c,
                    'amount' => orderRecord.Order_Total__c,
                    'customerName' => orderRecord.Customer__r == null ? null : orderRecord.Customer__r.Name,
                    'items' => new List<Object>()
                };
                List<Object> itemPayloads = (List<Object>)payload.get('items');
                for (Order_Item__c item : orderRecord.Order_Items__r) {
                    itemPayloads.add(new Map<String, Object>{
                        'productName' => item.Product__r == null ? null : item.Product__r.Name,
                        'productCode' => item.Product__r == null ? null : item.Product__r.Product_Code__c,
                        'quantity' => item.Quantity__c,
                        'unitPrice' => item.Unit_Price__c
                    });
                }

                HttpRequest request = new HttpRequest();
                request.setEndpoint('callout:' + namedCredential + '/orders');
                request.setMethod('POST');
                request.setHeader('Content-Type', 'application/json');
                request.setHeader('Idempotency-Key', String.valueOf(orderRecord.Id));
                request.setBody(JSON.serialize(payload));
                request.setTimeout(20000);

                HttpResponse response = client.send(request);
                String responseBody = response.getBody();
                if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                    ordersToUpdate.add(new Sales_Order__c(
                        Id=orderRecord.Id, Sync_Status__c='Failed',
                        Sync_Error__c=truncate('HTTP ' + response.getStatusCode() + ': ' + responseBody, 32768)
                    ));
                    continue;
                }

                Map<String, Object> responseJson = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
                String externalReference = firstNonBlank(responseJson, new List<String>{
                    'externalOrderId', 'orderReference', 'externalInvoiceId', 'invoiceId'
                });
                if (String.isBlank(externalReference)) {
                    ordersToUpdate.add(new Sales_Order__c(
                        Id=orderRecord.Id, Sync_Status__c='Failed',
                        Sync_Error__c='The integration response did not include an external order or invoice reference.'
                    ));
                    continue;
                }

                ordersToUpdate.add(new Sales_Order__c(
                    Id=orderRecord.Id,
                    External_Order_ID__c=truncate(externalReference, 100),
                    Sync_Status__c='Synced',
                    Sync_Error__c=null
                ));
                String externalInvoiceId = firstNonBlank(responseJson, new List<String>{'externalInvoiceId', 'invoiceId'});
                if (!String.isBlank(externalInvoiceId)) {
                    invoicesToInsert.add(new Invoice__c(
                        Sales_Order__c=orderRecord.Id,
                        Invoice_Amount__c=orderRecord.Order_Total__c,
                        Invoice_Date__c=Date.today(),
                        External_Invoice_ID__c=truncate(externalInvoiceId, 100),
                        Sync_Status__c='Synced',
                        API_Response__c=truncate(responseBody, 32768)
                    ));
                }
            } catch (Exception e) {
                ordersToUpdate.add(new Sales_Order__c(
                    Id=orderRecord.Id, Sync_Status__c='Failed',
                    Sync_Error__c=truncate(e.getMessage(), 32768)
                ));
            }
        }

        if (!invoicesToInsert.isEmpty()) insert invoicesToInsert;
        if (!ordersToUpdate.isEmpty()) update ordersToUpdate;
    }

    private static String firstNonBlank(Map<String, Object> values, List<String> keys) {
        for (String key : keys) {
            Object candidate = values.get(key);
            if (candidate != null && !String.isBlank(String.valueOf(candidate))) return String.valueOf(candidate);
        }
        return null;
    }

    private static String truncate(String value, Integer maxLength) {
        if (value == null || value.length() <= maxLength) return value;
        return value.substring(0, maxLength);
    }
}
