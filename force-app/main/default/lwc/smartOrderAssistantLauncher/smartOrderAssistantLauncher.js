import { LightningElement, api } from 'lwc';
import lookupProducts from '@salesforce/apex/StoreOperationsAssistantController.lookupProducts';

export default class SmartOrderAssistantLauncher extends LightningElement {
    @api botId; // Retained for existing Lightning page configuration compatibility.
    @api buttonLabel = 'Search';

    messages = [{
        id: 1,
        label: 'Assistant',
        text: 'Hi! Ask me to find one or more products by name or code. I can show each product’s current price, available stock, and description. I only look up products; I do not create orders.',
        className: 'assistant-message'
    }];
    searchText = '';
    isLoading = false;
    nextMessageId = 2;

    get isSendDisabled() {
        return this.isLoading || !this.searchText.trim();
    }

    handleInput(event) {
        this.searchText = event.target.value;
    }

    handleKeydown(event) {
        if (event.key === 'Enter' && !this.isSendDisabled) {
            event.preventDefault();
            this.handleSend();
        }
    }

    async handleSend() {
        const query = this.searchText.trim();
        if (!query || this.isLoading) return;

        this.appendMessage('You', query, 'user-message');
        this.searchText = '';
        this.isLoading = true;

        try {
            const result = await lookupProducts({ searchText: query });
            this.appendMessage('Assistant', result || 'No product details were returned.', 'assistant-message');
        } catch (error) {
            const message = error?.body?.message || error?.message || 'The product lookup failed. Check your access and try again.';
            this.appendMessage('Assistant', message, 'assistant-message error-message');
        } finally {
            this.isLoading = false;
        }
    }

    appendMessage(label, text, className) {
        this.messages = [...this.messages, {
            id: this.nextMessageId++,
            label,
            text,
            className
        }];
    }
}
