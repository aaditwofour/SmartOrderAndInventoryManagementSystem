List<Product__c> seedProducts = new List<Product__c>{
    new Product__c(Product_Code__c='LAP-001', Name='Laptop', Unit_Price__c=55000, Available_Quantity__c=20, Reorder_Level__c=5, Active__c=true),
    new Product__c(Product_Code__c='MOU-001', Name='Mouse', Unit_Price__c=800, Available_Quantity__c=50, Reorder_Level__c=10, Active__c=true),
    new Product__c(Product_Code__c='KEY-001', Name='Keyboard', Unit_Price__c=1500, Available_Quantity__c=30, Reorder_Level__c=5, Active__c=true),
    new Product__c(Product_Code__c='MON-001', Name='Monitor', Unit_Price__c=12000, Available_Quantity__c=15, Reorder_Level__c=5, Active__c=true),
    new Product__c(Product_Code__c='HDR-001', Name='Headphones', Unit_Price__c=2500, Available_Quantity__c=40, Reorder_Level__c=10, Active__c=true)
};

Set<String> productCodes = new Set<String>{'LAP-001', 'MOU-001', 'KEY-001', 'MON-001', 'HDR-001'};
Map<String, Product__c> existingProducts = new Map<String, Product__c>();
for (Product__c product : [SELECT Id, Product_Code__c FROM Product__c WHERE Product_Code__c IN :productCodes]) {
    existingProducts.put(product.Product_Code__c, product);
}

List<Product__c> productsToInsert = new List<Product__c>();
List<Product__c> productsToUpdate = new List<Product__c>();
for (Product__c seedProduct : seedProducts) {
    Product__c existing = existingProducts.get(seedProduct.Product_Code__c);
    if (existing == null) {
        productsToInsert.add(seedProduct);
    } else {
        existing.Name = seedProduct.Name;
        existing.Unit_Price__c = seedProduct.Unit_Price__c;
        existing.Available_Quantity__c = seedProduct.Available_Quantity__c;
        existing.Reorder_Level__c = seedProduct.Reorder_Level__c;
        existing.Active__c = seedProduct.Active__c;
        existing.Description__c = seedProduct.Description__c;
        productsToUpdate.add(existing);
    }
}
if (!productsToInsert.isEmpty()) insert productsToInsert;
if (!productsToUpdate.isEmpty()) update productsToUpdate;

Set<String> customerNames = new Set<String>{'ABC Technologies', 'XYZ Solutions'};
Set<String> existingCustomerNames = new Set<String>();
for (Customer__c customer : [SELECT Name FROM Customer__c WHERE Name IN :customerNames]) {
    existingCustomerNames.add(customer.Name);
}
List<Customer__c> customersToInsert = new List<Customer__c>();
for (String customerName : customerNames) {
    if (!existingCustomerNames.contains(customerName)) customersToInsert.add(new Customer__c(Name=customerName));
}
if (!customersToInsert.isEmpty()) insert customersToInsert;
