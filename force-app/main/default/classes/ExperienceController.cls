public with sharing class ExperienceController {
    static Integer PAGE_SIZE = 9;

    /**
     * Endpoint that retrieves the sessions associated with an experience and a date
     * @param experienceId Experience ID
     * @param timestamp Timestamp representing the date on which the sessions take place
     * @return List of Session__c records
     */
    @AuraEnabled(cacheable=true scope='global')
    public static List<Session__c> getExperienceSessionsForDate(
        Id experienceId,
        Long timestamp
    ) {
        Date dateFilter = Datetime.newInstance(timestamp).date();
        List<Session__c> sessions = [
            SELECT
                Id,
                Booked_Slots__c,
                Capacity__c,
                End_Time__c,
                Percentage_Booked__c,
                Start_Time__c,
                Status__c,
                Experience__r.Price__c
            FROM Session__c
            WHERE Experience__c = :experienceId AND Date__c = :dateFilter
            WITH SECURITY_ENFORCED
            ORDER BY Start_Time__c ASC
            LIMIT 10
        ];
        return sessions;
    }

    /**
     * Returns today's sessions for the experience type selected by a contact.
     * The contact's Interest1__c value is the Experience__c Type__c value.
     */
    @AuraEnabled(cacheable=true)
    public static List<Session__c> getSessions(Contact contactRecord) {
        if (contactRecord == null || String.isBlank(contactRecord.Interest1__c)) {
            return new List<Session__c>();
        }

        return [
            SELECT Id, Experience__c, Experience__r.Name, Date__c, Start_Time__c
            FROM Session__c
            WHERE Date__c = TODAY AND Experience__r.Type__c = :contactRecord.Interest1__c
            WITH SECURITY_ENFORCED
            ORDER BY Start_Time__c ASC
        ];
    }

    @AuraEnabled(Cacheable=true scope='global')
    public static PagedResult getExperiences(String type, Integer pageNumber) {
        String whereClause = '';
        if (type != null || type != '') {
            whereClause = 'WHERE Type__c = :type';
        }
        Integer pageSize = ExperienceController.PAGE_SIZE;
        Integer offset = (pageNumber - 1) * pageSize;
        PagedResult result = new PagedResult();
        result.pageSize = pageSize;
        result.pageNumber = pageNumber;
        result.totalItemCount = Database.countQuery(
            'SELECT count() FROM Experience__c ' + whereClause
        );
        result.records = Database.query(
            'SELECT Id, Name, Description__c, Rating__c, Picture_URL__c FROM Experience__c ' +
                whereClause +
                ' WITH SECURITY_ENFORCED' +
                ' ORDER BY Name LIMIT :pageSize OFFSET :offset'
        );
        return result;
    }

    public with sharing class PagedResult {
        @AuraEnabled
        public Integer pageSize { get; set; }
    
        @AuraEnabled
        public Integer pageNumber { get; set; }
    
        @AuraEnabled
        public Integer totalItemCount { get; set; }
    
        @AuraEnabled
        public Object[] records { get; set; }
    }
    
}
