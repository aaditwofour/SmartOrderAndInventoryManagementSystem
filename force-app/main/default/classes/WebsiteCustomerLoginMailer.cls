@RestResource(urlMapping='/website/customer-login/send-code')
global with sharing class WebsiteCustomerLoginMailer {
    global class LoginCodeRequest {
        global String email;
        global String code;
    }

    @HttpPost
    global static void sendCode() {
        RestResponse response = RestContext.response;
        response.addHeader('Content-Type', 'application/json');
        try {
            LoginCodeRequest requestBody = (LoginCodeRequest) JSON.deserialize(
                RestContext.request.requestBody.toString(),
                LoginCodeRequest.class
            );
            String emailAddress = requestBody == null || requestBody.email == null
                ? '' : requestBody.email.trim();
            String code = requestBody == null || requestBody.code == null
                ? '' : requestBody.code.trim();
            if (!Pattern.matches('(?i)^\\S+@\\S+\\.\\S+$', emailAddress)
                || !Pattern.matches('^[0-9]{6}$', code)) {
                response.statusCode = 400;
                response.responseBody = Blob.valueOf('{"error":"Invalid email or code."}');
                return;
            }

            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.setToAddresses(new String[] { emailAddress });
            message.setSubject('Your Field & Form sign-in code');
            message.setPlainTextBody(
                'Your Field & Form sign-in code is ' + code + '. It expires in 10 minutes. ' +
                'If you did not request this code, you can ignore this email.'
            );
            message.setSaveAsActivity(false);
            Messaging.SendEmailResult[] results = Messaging.sendEmail(
                new Messaging.SingleEmailMessage[] { message }, false
            );
            if (results.isEmpty() || !results[0].isSuccess()) {
                response.statusCode = 502;
                response.responseBody = Blob.valueOf('{"error":"Salesforce could not send the sign-in email."}');
                return;
            }
            response.statusCode = 200;
            response.responseBody = Blob.valueOf('{"sent":true}');
        } catch (Exception error) {
            response.statusCode = 400;
            response.responseBody = Blob.valueOf('{"error":"The sign-in email could not be sent."}');
        }
    }
}