@RestResource(urlMapping='/website/analytics/visit')
global with sharing class StorefrontAnalyticsApi {
    private static final Pattern HASHED_KEY = Pattern.compile('^[a-fA-F0-9]{64}$');

    @HttpPost
    global static void recordPageView() {
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
                RestContext.request.requestBody.toString()
            );
            String visitorKey = stringValue(payload.get('visitorKey'));
            String sessionKey = stringValue(payload.get('sessionKey'));
            String pageViewKey = stringValue(payload.get('pageViewKey'));
            String pagePath = stringValue(payload.get('path'));

            if (!isHashedKey(visitorKey) || !isHashedKey(sessionKey) || !isHashedKey(pageViewKey)) {
                writeResponse(400, new Map<String, Object>{ 'error' => 'Invalid analytics identifiers.' });
                return;
            }
            if (String.isBlank(pagePath)) pagePath = '/';
            if (!pagePath.startsWith('/') || pagePath.length() > 255) {
                writeResponse(400, new Map<String, Object>{ 'error' => 'Invalid page path.' });
                return;
            }

            Datetime nowValue = System.now();
            List<Storefront_Visitor__c> matches = [
                SELECT Id, First_Seen__c, Last_Seen__c, Last_Session_Key__c,
                       Total_Sessions__c, Total_Page_Views__c
                FROM Storefront_Visitor__c
                WHERE Visitor_Key__c = :visitorKey
                LIMIT 1
                FOR UPDATE
            ];

            Storefront_Visitor__c visitor;
            if (matches.isEmpty()) {
                visitor = new Storefront_Visitor__c(
                    Visitor_Key__c = visitorKey,
                    First_Seen__c = nowValue,
                    Last_Seen__c = nowValue,
                    Total_Sessions__c = 0,
                    Total_Page_Views__c = 0
                );
                try {
                    insert visitor;
                } catch (DmlException duplicateInsert) {
                    if (String.valueOf(duplicateInsert.getDmlStatusCode(0)) != 'DUPLICATE_VALUE') throw duplicateInsert;
                    matches = [
                        SELECT Id, First_Seen__c, Last_Seen__c, Last_Session_Key__c,
                               Total_Sessions__c, Total_Page_Views__c
                        FROM Storefront_Visitor__c
                        WHERE Visitor_Key__c = :visitorKey
                        LIMIT 1
                        FOR UPDATE
                    ];
                    if (matches.isEmpty()) throw duplicateInsert;
                    visitor = matches[0];
                }
            } else {
                visitor = matches[0];
            }

            List<Storefront_Page_View__c> existingViews = [
                SELECT Id
                FROM Storefront_Page_View__c
                WHERE Page_View_Key__c = :pageViewKey
                LIMIT 1
            ];
            if (existingViews.isEmpty()) {
                Decimal sessionCount = visitor.Total_Sessions__c == null ? 0 : visitor.Total_Sessions__c;
                Decimal viewCount = visitor.Total_Page_Views__c == null ? 0 : visitor.Total_Page_Views__c;
                if (visitor.Last_Session_Key__c != sessionKey) {
                    sessionCount++;
                    visitor.Last_Session_Key__c = sessionKey;
                }
                viewCount++;
                visitor.Total_Sessions__c = sessionCount;
                visitor.Total_Page_Views__c = viewCount;
                if (visitor.First_Seen__c == null) visitor.First_Seen__c = nowValue;
                visitor.Last_Seen__c = nowValue;
                visitor.Last_Page__c = pagePath;
                update visitor;

                insert new Storefront_Page_View__c(
                    Page_View_Key__c = pageViewKey,
                    Visitor__c = visitor.Id,
                    Viewed_At__c = nowValue,
                    Page_Path__c = pagePath
                );
            }

            visitor = [
                SELECT Total_Sessions__c, Total_Page_Views__c, Is_Repeat_Visitor__c
                FROM Storefront_Visitor__c
                WHERE Id = :visitor.Id
                LIMIT 1
            ];
            writeResponse(200, new Map<String, Object>{
                'sessions' => visitor.Total_Sessions__c,
                'pageViews' => visitor.Total_Page_Views__c,
                'repeatVisitor' => visitor.Is_Repeat_Visitor__c
            });
        } catch (Exception errorValue) {
            writeResponse(500, new Map<String, Object>{ 'error' => 'Could not record this storefront visit.' });
        }
    }

    private static Boolean isHashedKey(String value) {
        return value != null && HASHED_KEY.matcher(value).matches();
    }

    private static String stringValue(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static void writeResponse(Integer statusCode, Map<String, Object> payload) {
        RestContext.response.statusCode = statusCode;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(payload));
    }
}
