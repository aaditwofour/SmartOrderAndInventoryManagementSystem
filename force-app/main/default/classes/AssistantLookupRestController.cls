@RestResource(urlMapping='/assistant/lookup/*')
global with sharing class AssistantLookupRestController {
    @HttpGET
    global static LookupResponse lookup() {
        RestRequest request = RestContext.request;
        String lookupType = request.params.get('lookupType');
        String lookupValue = request.params.get('lookupValue');
        String customerEmail = request.params.get('customerEmail');

        if (String.isBlank(lookupType)) {
            return new LookupResponse('Choose a lookup type: CHECK_STOCK, PENDING_APPROVALS, ORDER_DETAILS, or INVOICE_STATUS.');
        }

        OrderAssistantLookupAction.Request lookupRequest = new OrderAssistantLookupAction.Request();
        lookupRequest.lookupType = lookupType;
        lookupRequest.lookupValue = lookupValue;
        lookupRequest.customerEmail = customerEmail;

        try {
            List<OrderAssistantLookupAction.Response> results = OrderAssistantLookupAction.execute(
                new List<OrderAssistantLookupAction.Request>{ lookupRequest }
            );
            return new LookupResponse(results.isEmpty() ? null : results[0].resultText);
        } catch (Exception e) {
            return new LookupResponse('The lookup could not be completed. Check record access and try again.');
        }
    }

    global class LookupResponse {
        public String resultText;
        public LookupResponse(String resultText) {
            this.resultText = resultText;
        }
    }
}
