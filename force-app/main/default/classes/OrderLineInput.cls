public class OrderLineInput {
    @AuraEnabled public Id productId { get; set; }
    @AuraEnabled public Decimal quantity { get; set; }
}
