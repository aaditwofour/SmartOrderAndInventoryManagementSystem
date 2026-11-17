(function loadFieldFormAgentforceMessaging() {
    const messagingState = window.fieldFormAgentforceMessaging || (window.fieldFormAgentforceMessaging = {
        ready: false,
        failed: false
    });
    const script = document.createElement('script');
    script.src = 'https://valuehub72-dev-ed.develop.my.site.com/ESWESAWebDeployment1724800920657/assets/js/bootstrap.min.js';
    script.async = true;
    script.onload = function initializeFieldFormAgentforceMessaging() {
        try {
            window.embeddedservice_bootstrap.settings.language = 'en_US';
            window.embeddedservice_bootstrap.init(
                '00Dfj00000qAATCEA4',
                'ESA_Web_Deployment',
                'https://valuehub72-dev-ed.develop.my.site.com/ESWESAWebDeployment1724800920657',
                { scrt2URL: 'https://valuehub72-dev-ed.develop.my.salesforce-scrt.com' }
            );
        } catch (error) {
            console.error('Agentforce Messaging could not be initialized.');
            messagingState.failed = true;
            window.dispatchEvent(new Event('fieldFormAgentforceMessagingError'));
        }
    };
    script.onerror = function reportAgentforceMessagingLoadError() {
        console.error('Agentforce Messaging resources could not be loaded.');
        messagingState.failed = true;
        window.dispatchEvent(new Event('fieldFormAgentforceMessagingError'));
    };
    document.head.appendChild(script);
}());
