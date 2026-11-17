@IsTest
private class CoverageGateRecoveryTest {
    @IsTest
    static void checkWeatherReturnsInvocableValues() {
        Test.setMock(
            HttpCalloutMock.class,
            new WeatherResponseMock(200, '{"weather":[{"temperature":10},{"temperature":30}]}')
        );
        CheckWeather.WeatherRequest request = new CheckWeather.WeatherRequest();
        request.dateToCheck = Date.today();

        Test.startTest();
        List<CheckWeather.WeatherResponse> responses = CheckWeather.getWeather(
            new List<CheckWeather.WeatherRequest>{ request }
        );
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.areEqual(10, responses[0].minTemperature);
        Assert.areEqual(30, responses[0].maxTemperature);
        Assert.isTrue(responses[0].temperatureDescription.contains('Coral Cloud'));
    }

    @IsTest
    static void personalizedExperiencesSerializesSessions() {
        Contact contactRecord = new Contact(
            FirstName = 'Test',
            LastName = 'Guest',
            Interest1__c = 'Cultural Tours & Workshops'
        );
        insert contactRecord;
        PersonalizedGuestExperiences.Request request = new PersonalizedGuestExperiences.Request();
        request.myContact = contactRecord;

        Test.startTest();
        List<PersonalizedGuestExperiences.Response> responses = PersonalizedGuestExperiences.getSessions(
            new List<PersonalizedGuestExperiences.Request>{ request }
        );
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.areEqual('[]', responses[0].prompt);
    }

    @IsTest
    static void assistantLookupReturnsInstructionsForMissingType() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/assistant/lookup';
        request.httpMethod = 'GET';
        request.params.put('lookupValue', 'keyboard');
        RestContext.request = request;

        Test.startTest();
        AssistantLookupRestController.LookupResponse response = AssistantLookupRestController.lookup();
        Test.stopTest();

        Assert.isTrue(response.resultText.contains('CHECK_STOCK'));
    }

    @IsTest
    static void loginMailerRejectsInvalidEmailOrCode() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/website/customer-login/send-code';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"email":"not-an-email","code":"123"}');
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebsiteCustomerLoginMailer.sendCode();
        Test.stopTest();

        Assert.areEqual(400, RestContext.response.statusCode);
        Assert.isTrue(RestContext.response.responseBody.toString().contains('Invalid email or code'));
    }

    @IsTest
    static void simpleControllersReturnStableResults() {
        Test.startTest();
        Boolean community = ContextService.isCommunity();
        String socialResponse = SocialMediaController.generatePosts('unused-session');
        Test.stopTest();

        Assert.isFalse(community);
        Assert.isTrue(socialResponse.contains('TODO'));
    }

    private class WeatherResponseMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        WeatherResponseMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(responseBody);
            return response;
        }
    }
}
