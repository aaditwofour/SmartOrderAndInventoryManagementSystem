const state = {
    products: [],
    source: 'demo',
    status: null,
    cart: new Map(),
    currency: 'INR',
    requestId: null,
    customerProfile: null,
    caseFlow: null
};

const $ = selector => document.querySelector(selector);
const html = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
const money = value => new Intl.NumberFormat('en-IN', { style: 'currency', currency: state.currency, maximumFractionDigits: 2 }).format(Number(value) || 0);
const GUEST_CART_KEY = 'field-form-cart:guest';
const VISITOR_ID_KEY = 'field-form-analytics:visitor';
const VISIT_SESSION_KEY = 'field-form-analytics:session';
let customerCartSaveTimer = null;

async function api(path, options = {}) {
    const response = await fetch(path, {
        ...options,
        headers: { ...(options.body ? { 'Content-Type': 'application/json' } : {}), ...(options.headers || {}) }
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data.error || `Request failed (${response.status}).`);
    return data;
}

function getAnalyticsVisitorId() {
    let visitorId = localStorage.getItem(VISITOR_ID_KEY);
    if (!visitorId) {
        visitorId = crypto.randomUUID();
        localStorage.setItem(VISITOR_ID_KEY, visitorId);
    }
    return visitorId;
}

function getAnalyticsSessionId() {
    const now = Date.now();
    let session;
    try { session = JSON.parse(localStorage.getItem(VISIT_SESSION_KEY) || 'null'); } catch { session = null; }
    if (!session?.id || now - Number(session.lastSeen || 0) > 30 * 60 * 1000) {
        session = { id: crypto.randomUUID(), lastSeen: now };
    } else {
        session.lastSeen = now;
    }
    localStorage.setItem(VISIT_SESSION_KEY, JSON.stringify(session));
    return session.id;
}

function recordPageView() {
    api('/api/analytics/page-view', {
        method: 'POST',
        body: JSON.stringify({
            visitorId: getAnalyticsVisitorId(),
            sessionId: getAnalyticsSessionId(),
            pageViewId: crypto.randomUUID(),
            path: `${location.pathname}${location.hash}`
        })
    }).catch(() => {});
}

function setError(element, message = '') {
    element.textContent = message;
    element.classList.toggle('hidden', !message);
}

function toast(message) {
    const element = $('#toast');
    element.textContent = message;
    element.classList.add('is-visible');
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => element.classList.remove('is-visible'), 3200);
}

function productArtClass(product, index) {
    const value = `${product.Product_Code__c || ''}${product.Name || ''}`;
    let hash = index;
    for (const char of value) hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
    return `product-art tone-${hash % 5}`;
}

function renderCategories() {
    const categories = ['All items', ...new Set(state.products.map(product => product.Category__c).filter(Boolean))];
    const root = $('#categoryFilters');
    root.innerHTML = categories.map((category, index) => `<button class="category-chip${index === 0 ? ' is-active' : ''}" type="button" data-category="${html(category)}">${html(category)}</button>`).join('');
    root.dataset.active = 'All items';
}

function renderQuickCategories() {
    const root = $('#quickCategoryGrid');
    const groups = [...new Set(state.products.map(product => product.Category__c).filter(Boolean))];
    const entries = groups.length
        ? groups.slice(0, 6).map(name => ({ name, query: name, category: name }))
        : [...new Map(state.products.map(product => [product.Name, { name: product.Name, query: product.Name, category: '' }])).values()].slice(0, 6);
    const icons = ['▣', '⌨', '◉', '▤', '♫', '✦'];
    root.innerHTML = entries.map((entry, index) => `<button class="quick-category-card" type="button" data-quick-query="${html(entry.query)}" data-quick-category="${html(entry.category)}"><span class="quick-category-icon">${icons[index % icons.length]}</span><strong>${html(entry.name)}</strong><small>Shop now <span>↗</span></small></button>`).join('');
}

function filteredProducts() {
    const query = $('#productSearch').value.trim().toLowerCase();
    const category = $('#categoryFilters').dataset.active || 'All items';
    return state.products.filter(product => {
        const matchesCategory = category === 'All items' || product.Category__c === category;
        const text = [product.Name, product.Product_Code__c, product.Description__c].join(' ').toLowerCase();
        return matchesCategory && (!query || text.includes(query));
    });
}

function renderProducts() {
    const products = filteredProducts();
    const grid = $('#productGrid');
    grid.innerHTML = products.map((product, index) => {
        const available = Number(product.Available_Quantity__c || 0);
        const quantity = state.cart.get(product.Id) || 0;
        const preview = String(product.Id).startsWith('preview-');
        const description = product.Description__c || 'A useful everyday essential, chosen for quality and lasting utility.';
        const stockLabel = preview ? 'Preview item' : available > 0 ? (available <= Number(product.Reorder_Level__c || 0) ? 'Running low' : 'In stock') : 'Out of stock';
        return `<article class="product-card">
            <div class="product-image ${productArtClass(product, index)}" aria-hidden="true"><span class="product-ribbon">${html(product.Product_Code__c || 'F&amp;F ESSENTIAL')}</span><span class="stock-badge${available <= Number(product.Reorder_Level__c || 0) && !preview ? ' low' : ''}"></span><div class="product-shape"><span class="shape-mark">F&amp;F</span><span class="shape-lines">EVERYDAY<br>ESSENTIALS</span><span class="shape-code">${String(index + 1).padStart(2, '0')} / FIELD</span></div></div>
            <div class="product-info"><div class="product-meta"><span>${html(product.Product_Code__c || 'FIELD & FORM')}</span><span>${html(stockLabel)}</span></div>
            <h3 class="product-name">${html(product.Name)}</h3><p class="product-description">${html(description)}</p>
            <div class="product-buy"><strong class="product-price">${money(product.Unit_Price__c)}</strong><button class="add-to-bag" type="button" data-add="${html(product.Id)}" aria-label="Add ${html(product.Name)} to cart" title="Add ${html(product.Name)} to cart" ${(!preview && available < 1) ? 'disabled' : ''}><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h2l2.1 10.1a2 2 0 0 0 2 1.6h7.8a2 2 0 0 0 1.9-1.4L21 8H6"/><circle cx="10" cy="20" r="1"/><circle cx="18" cy="20" r="1"/></svg>${quantity ? `<b class="product-cart-quantity" aria-label="${quantity} in cart">${quantity}</b>` : ''}</button></div></div>
        </article>`;
    }).join('');
    $('#emptyState').classList.toggle('hidden', products.length > 0);
    $('#catalogStatus').textContent = `${products.length} ${products.length === 1 ? 'piece' : 'pieces'} in the collection`;
}

function renderCart() {
    const rows = [...state.cart.entries()].map(([id, quantity]) => ({ product: state.products.find(item => item.Id === id), quantity })).filter(row => row.product);
    const count = rows.reduce((sum, row) => sum + row.quantity, 0);
    const subtotal = rows.reduce((sum, row) => sum + Number(row.product.Unit_Price__c || 0) * row.quantity, 0);
    $('#cartCount').textContent = String(count);
    $('#cartHeadingCount').textContent = `(${count})`;
    $('#cartEmpty').classList.toggle('hidden', rows.length > 0);
    $('#cartSummary').classList.toggle('hidden', rows.length === 0);
    $('#cartItems').innerHTML = rows.map(({ product, quantity }) => `<div class="cart-line"><div class="cart-line-art ${productArtClass(product, 1)}"><span class="art-wordmark">F&amp;F</span></div><div class="cart-line-copy"><strong>${html(product.Name)}</strong><small>${money(product.Unit_Price__c)} each</small><div class="quantity-control"><button type="button" data-quantity="${html(product.Id)}" data-change="-1" aria-label="Remove one ${html(product.Name)}">−</button><span>${quantity}</span><button type="button" data-quantity="${html(product.Id)}" data-change="1" aria-label="Add one ${html(product.Name)}">+</button><button class="remove-line" type="button" data-remove="${html(product.Id)}">Remove</button></div></div><strong class="cart-line-total">${money(Number(product.Unit_Price__c || 0) * quantity)}</strong></div>`).join('');
    $('#cartSubtotal').textContent = money(subtotal);
    renderProducts();
}

function scrollToBag() {
    $('#shoppingBag').scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function renderConnection() {
    const connected = Boolean(state.status?.connected);
    const preview = !connected;
    $('#connectionPill').classList.toggle('is-connected', connected);
    $('#connectionPill').classList.toggle('is-preview', !connected);
    $('#connectionPill').querySelector('span').textContent = connected ? 'Salesforce live' : 'Preview store';
    $('#previewBanner').classList.toggle('hidden', !preview);
    $('#adminConnectionDot').classList.toggle('is-connected', connected);
    $('#adminConnectionTitle').textContent = connected ? 'Salesforce connected' : 'Not connected';
    $('#adminConnectionHelp').textContent = connected ? 'Live product stock and orders are enabled.' : state.status?.oauthConfigured ? 'Connect Salesforce to load live products and accept orders.' : 'Add the External Client App details to website/.env first.';
    $('#connectSalesforceButton').classList.toggle('hidden', connected);
    $('#disconnectSalesforceButton').classList.toggle('hidden', !connected);
    $('#refreshOrdersButton').disabled = !connected;
    $('#productForm').querySelectorAll('input,textarea,button').forEach(input => input.disabled = !connected);
    $('#customerLoginHelp').textContent = connected
        ? 'Sign in with a one-time code sent to the email on your customer account. We’ll use it to fill your checkout details.'
        : 'Customer sign-in becomes available after the store admin connects Salesforce.';
}

function renderCustomerProfile() {
    const profile = state.customerProfile;
    const name = profile?.name?.trim() || '';
    $('#customerSignIn').textContent = profile ? `Hi, ${name.split(/\s+/)[0] || 'there'}` : 'Sign in';
    $('#customerLoginTitle').textContent = profile ? 'Your account' : 'Sign in';
    $('#customerSignedOutView').classList.toggle('hidden', Boolean(profile));
    $('#customerSignedInView').classList.toggle('hidden', !profile);
    if (profile) {
        $('#customerProfileName').textContent = profile.name || 'Customer account';
        $('#customerProfileEmail').textContent = profile.email || '';
    }
}

function applyCustomerProfile(profile) {
    state.customerProfile = profile;
    const form = $('#checkoutForm');
    form.elements.name.value = profile.name || '';
    form.elements.email.value = profile.email || '';
    form.elements.phone.value = profile.phone || '';
    form.elements.billingAddress.value = profile.billingAddress || '';
    form.elements.customerType.value = profile.customerType === 'Business' ? 'Business' : 'Individual';
    form.elements.businessName.value = profile.businessName || '';
    form.elements.customerType.dispatchEvent(new Event('change'));
    renderCustomerProfile();
}

async function refreshCatalog() {
    const [status, catalog] = await Promise.all([api('/api/status'), api('/api/products')]);
    state.status = status;
    state.source = catalog.source;
    state.products = catalog.products || [];
    state.currency = status.currency || 'INR';
    renderConnection();
    renderCategories();
    renderQuickCategories();
    renderProducts();
    renderCart();
}

function cartStorageKey(email = state.customerProfile?.email) {
    return email ? `field-form-cart:${email.trim().toLowerCase()}` : GUEST_CART_KEY;
}

function readStoredCart(key) {
    try {
        const saved = JSON.parse(localStorage.getItem(key) || '[]');
        return Array.isArray(saved) ? saved : [];
    } catch { return []; }
}

function applySavedCart(items) {
    const availableIds = new Set(state.products.map(product => product.Id));
    state.cart = new Map((items || [])
        .filter(item => availableIds.has(item.productId) && Number.isInteger(Number(item.quantity)) && Number(item.quantity) > 0)
        .map(item => [item.productId, Number(item.quantity)]));
    renderProducts();
    renderCart();
}

async function restoreCustomerProgress(profile) {
    const guestCart = readStoredCart(GUEST_CART_KEY);
    const saved = await api('/api/customer-progress');
    const merged = new Map((saved.cart || []).map(item => [item.productId, Number(item.quantity)]));
    for (const item of guestCart) merged.set(item.productId, (merged.get(item.productId) || 0) + Number(item.quantity || 0));
    const cart = [...merged.entries()].map(([productId, quantity]) => ({ productId, quantity }));
    applySavedCart(cart);
    localStorage.setItem(cartStorageKey(profile.email), JSON.stringify(cart));
    if (guestCart.length) {
        await api('/api/customer-progress', { method: 'PUT', body: JSON.stringify({ cart }) });
        localStorage.removeItem(GUEST_CART_KEY);
    }
}

async function restoreGuestCart() {
    applySavedCart(readStoredCart(GUEST_CART_KEY));
}

function scheduleCartSave() {
    const cart = [...state.cart.entries()].map(([productId, quantity]) => ({ productId, quantity }));
    localStorage.setItem(cartStorageKey(), JSON.stringify(cart));
    clearTimeout(customerCartSaveTimer);
    if (!state.customerProfile) return;
    customerCartSaveTimer = setTimeout(async () => {
        try {
            await api('/api/customer-progress', { method: 'PUT', body: JSON.stringify({ cart }) });
            localStorage.removeItem(GUEST_CART_KEY);
        } catch (error) {
            toast(`Your cart is saved on this device. ${error.message}`);
        }
    }, 300);
}

function formData(form) {
    return Object.fromEntries(new FormData(form).entries());
}

function assistantToggle(open) {
    const panel = $('#assistantPanel');
    const launch = $('#assistantLaunch');
    const isOpen = panel.classList.contains('is-open');
    const next = open === undefined ? !isOpen : open;
    panel.classList.toggle('is-open', next);
    launch.classList.toggle('is-open', next);
    launch.setAttribute('aria-expanded', String(next));
    panel.setAttribute('aria-hidden', String(!next));
    if (next) {
        $('#assistantInput').focus();
        if (!$('#assistantBody').dataset.seeded) {
            $('#assistantBody').dataset.seeded = '1';
            if (!state.status?.connected) assistantPush('I can only answer questions after the store admin connects Salesforce.', 'bot');
        }
    }
}

function assistantPush(text, who = 'bot') {
    const body = $('#assistantBody');
    const wrap = document.createElement('div');
    wrap.className = `assistant-message assistant-message-${who}`;
    const bubble = document.createElement('div');
    bubble.className = 'assistant-bubble';
    bubble.textContent = text;
    const avatar = document.createElement('span');
    avatar.className = 'assistant-avatar';
    avatar.textContent = who === 'user' ? 'You' : '✦';
    wrap.appendChild(avatar);
    wrap.appendChild(bubble);
    body.appendChild(wrap);
    body.scrollTop = body.scrollHeight;
}

function assistantThinking(on) {
    const body = $('#assistantBody');
    if (on) {
        const wrap = document.createElement('div');
        wrap.className = 'assistant-thinking';
        wrap.innerHTML = '<span></span><span></span><span></span>';
        body.appendChild(wrap);
        body.scrollTop = body.scrollHeight;
    } else {
        const existing = body.querySelector('.assistant-thinking');
        if (existing) existing.remove();
    }
}

function startsSupportCaseRequest(question) {
    return /\b(?:create|open|raise|file|submit|log)\b[\s\S]{0,50}\b(?:support\s+)?(?:ticket|case)\b/i.test(question)
        || /\b(?:ticket|case)\b[\s\S]{0,35}\b(?:create|open|raise|file|submit)\b/i.test(question);
}

function startSupportCaseFlow() {
    if (!state.status?.connected) {
        assistantPush('I can create a support ticket once the store is connected to Salesforce.', 'bot');
        return;
    }
    state.caseFlow = { step: 'subject', subject: '', description: '', name: '', email: '' };
    assistantPush('I can create a Salesforce support case. What short title should I use for the issue?', 'bot');
}

async function continueSupportCaseFlow(answer) {
    const flow = state.caseFlow;
    const value = answer.trim();
    if (/^(cancel|stop|never mind|nevermind)$/i.test(value)) {
        state.caseFlow = null;
        assistantPush('Okay, I cancelled the support ticket request. No case was created.', 'bot');
        return;
    }

    if (flow.step === 'subject') {
        if (value.length < 5 || value.length > 120) {
            assistantPush('Please enter a short title between 5 and 120 characters.', 'bot');
            return;
        }
        flow.subject = value;
        flow.step = 'description';
        assistantPush('Please describe what happened and what help you need. Leave out passwords and payment details.', 'bot');
        return;
    }
    if (flow.step === 'description') {
        if (value.length < 20 || value.length > 2000) {
            assistantPush('Please add at least 20 characters of detail (up to 2,000).', 'bot');
            return;
        }
        flow.description = value;
        flow.step = 'name';
        assistantPush('What name should support see on the case? You can reply “skip”.', 'bot');
        return;
    }
    if (flow.step === 'name') {
        flow.name = /^skip$/i.test(value) ? '' : value;
        if (flow.name.length > 120) {
            assistantPush('Please use a name under 120 characters, or reply “skip”.', 'bot');
            return;
        }
        flow.step = 'email';
        assistantPush('What email may support use to follow up? It is optional; reply “skip” to omit it.', 'bot');
        return;
    }
    if (flow.step === 'email') {
        flow.email = /^skip$/i.test(value) ? '' : value;
        if (flow.email && !/^\S+@\S+\.\S+$/.test(flow.email)) {
            assistantPush('That email does not look valid. Please try again or reply “skip”.', 'bot');
            return;
        }
        flow.step = 'confirm';
        const contactLine = flow.email ? `Follow-up email: ${flow.email}.` : 'No follow-up email was provided.';
        const nameLine = flow.name ? `Name: ${flow.name}. ` : '';
        assistantPush(`Please review the case: “${flow.subject}”. Details: ${flow.description} ${nameLine}${contactLine} Reply YES to create this Salesforce case, or CANCEL to discard it.`, 'bot');
        return;
    }
    if (flow.step === 'confirm') {
        if (!/^(yes|yes please|create|submit|confirm|go ahead)$/i.test(value)) {
            assistantPush('Reply YES to create this case, or CANCEL to discard it.', 'bot');
            return;
        }
        flow.step = 'submitting';
        assistantThinking(true);
        try {
            const result = await api('/api/cases', {
                method: 'POST',
                body: JSON.stringify({ subject: flow.subject, description: flow.description, name: flow.name, email: flow.email })
            });
            state.caseFlow = null;
            assistantPush(`Your support case was created in Salesforce. Case reference: ${result.caseId}.`, 'bot');
        } catch (error) {
            flow.step = 'confirm';
            assistantPush(error.message || 'I could not create the support case. Please try again.', 'bot');
        } finally {
            assistantThinking(false);
        }
    }
}

async function assistantAsk(event) {
    event.preventDefault();
    const input = $('#assistantInput');
    const question = input.value.trim();
    if (!question) return;
    assistantPush(question, 'user');
    input.value = '';
    if (state.caseFlow) {
        if (state.caseFlow.step === 'submitting') return;
        await continueSupportCaseFlow(question);
        return;
    }
    if (startsSupportCaseRequest(question)) {
        startSupportCaseFlow();
        return;
    }
    assistantThinking(true);
    const orderQuestion = /\b(order|invoice|track|tracking|shipment|delivery)\b/i.test(question);
    const productQuestion = /\b(product|price|cost|stock|available|availability|inventory|quantity|reorder|laptop|mouse|keyboard|monitor|headphones?)\b/i.test(question)
        || /\b[A-Z]{2,8}-\d{3,}\b/i.test(question);
    try {
        let data;
        if (orderQuestion) {
            data = await api('/api/assistant/order', { method: 'POST', body: JSON.stringify({ question }) });
        } else if (state.status?.connected && state.status?.geminiConfigured) {
            data = await api('/api/chat', { method: 'POST', body: JSON.stringify({ message: question }) });
        } else if (productQuestion || !state.status?.geminiConfigured) {
            data = await api('/api/assistant/query', { method: 'POST', body: JSON.stringify({ question }) });
        } else {
            assistantPush('I can help with product prices, stock, and order tracking. Ask about a product, or sign in to track an order.', 'bot');
            return;
        }
        assistantPush(data.answer || data.resultText || 'I could not find an answer.', 'bot');
    } catch (error) {
        assistantPush(error.message || 'I could not answer that question.', 'bot');
    } finally {
        assistantThinking(false);
    }
}

function setBusy(button, busy, label) {
    if (busy) {
        button.dataset.originalLabel = button.innerHTML;
        button.disabled = true;
        button.textContent = label;
    } else {
        button.disabled = false;
        button.innerHTML = button.dataset.originalLabel || label;
    }
}

function renderOrderDashboard(data) {
    const metrics = data.metrics || {};
    $('#activeOrderCount').textContent = String(metrics.active || 0);
    $('#approvalOrderCount').textContent = String(metrics.awaitingApproval || 0);
    $('#processingOrderCount').textContent = String(metrics.processing || 0);
    $('#activeOrderValue').textContent = money(metrics.activeValue || 0);
    $('#orderMetrics').classList.remove('hidden');
    const rows = data.orders || [];
    $('#orderDashboardRows').innerHTML = rows.length ? rows.map(order => {
        const date = order.date ? new Date(order.date).toLocaleDateString() : '—';
        return `<tr><td><strong>${html(order.number)}</strong><small>${html(date)}</small></td><td>${html(order.customerName)}</td><td><span class="order-status-pill">${html(order.status)}</span></td><td>${html(order.approvalStatus)}</td><td>${money(order.total)}</td></tr>`;
    }).join('') : '<tr><td colspan="5">No orders have been placed yet.</td></tr>';
}

async function loadOrderDashboard() {
    const key = $('#adminKeyInput').value || sessionStorage.getItem('storeAdminKey') || '';
    const error = $('#ordersDashboardError');
    const button = $('#refreshOrdersButton');
    setError(error);
    if (!key) return setError(error, 'Enter the website admin key above to view orders.');
    sessionStorage.setItem('storeAdminKey', key);
    setBusy(button, true, 'Loading…');
    try {
        const data = await api('/api/admin/orders', { headers: { 'x-admin-key': key } });
        renderOrderDashboard(data);
    } catch (err) {
        setError(error, err.message);
    } finally {
        setBusy(button, false, 'Refresh');
        button.disabled = !state.status?.connected;
    }
}

function startCheckout() {
    if (!state.status?.connected) {
        toast('Connect Salesforce in Store admin before placing a live order.');
        return;
    }
    if (!state.cart.size) return;
    $('#checkoutModal').showModal();
}

function showOrderResult(result) {
    $('#resultTitle').textContent = 'Thank you.';
    $('#resultCopy').textContent = 'Your order has been created in Salesforce. We’ll use the details you provided to follow up.';
    $('#resultOrderNumber').textContent = result.orderNumber || 'Submitted';
    $('#resultStatus').textContent = result.status || 'Submitted';
    $('#resultApproval').textContent = result.approvalStatus || 'Pending';
    $('#resultTotal').textContent = money(result.total);
    $('#resultModal').showModal();
}

$('#year').textContent = new Date().getFullYear();
$('#assistantLaunch').addEventListener('click', () => assistantToggle());
$('#assistantClose').addEventListener('click', () => assistantToggle(false));
$('#assistantForm').addEventListener('submit', assistantAsk);
$('#productSearch').addEventListener('input', renderProducts);

$('#quickCategoryGrid').addEventListener('click', event => {
    const card = event.target.closest('[data-quick-query]');
    if (!card) return;
    if (card.dataset.quickCategory) {
        $('#categoryFilters').dataset.active = card.dataset.quickCategory;
        $('#categoryFilters').querySelectorAll('.category-chip').forEach(chip => chip.classList.toggle('is-active', chip.dataset.category === card.dataset.quickCategory));
        $('#productSearch').value = '';
    } else {
        $('#categoryFilters').dataset.active = 'All items';
        $('#categoryFilters').querySelectorAll('.category-chip').forEach((chip, index) => chip.classList.toggle('is-active', index === 0));
        $('#productSearch').value = card.dataset.quickQuery;
    }
    renderProducts();
    $('#catalog').scrollIntoView({ behavior: 'smooth', block: 'start' });
});
$('#categoryFilters').addEventListener('click', event => {
    const button = event.target.closest('[data-category]');
    if (!button) return;
    $('#categoryFilters').dataset.active = button.dataset.category;
    $('#categoryFilters').querySelectorAll('.category-chip').forEach(chip => chip.classList.toggle('is-active', chip === button));
    renderProducts();
});
$('#productGrid').addEventListener('click', event => {
    const button = event.target.closest('[data-add]');
    if (!button) return;
    const product = state.products.find(item => item.Id === button.dataset.add);
    if (!product) return;
    const current = state.cart.get(product.Id) || 0;
    if (!String(product.Id).startsWith('preview-') && current >= Number(product.Available_Quantity__c || 0)) return toast('There is not enough stock for another item.');
    state.cart.set(product.Id, current + 1);
    renderCart();
    scheduleCartSave();
    toast(`${product.Name} added to your bag.`);
});
function updateCartFromEvent(event) {
    const remove = event.target.closest('[data-remove]');
    if (remove) state.cart.delete(remove.dataset.remove);
    const adjust = event.target.closest('[data-quantity]');
    if (adjust) {
        const id = adjust.dataset.quantity;
        const quantity = (state.cart.get(id) || 0) + Number(adjust.dataset.change);
        if (quantity < 1) state.cart.delete(id);
        else {
            const product = state.products.find(item => item.Id === id);
            if (!String(id).startsWith('preview-') && quantity > Number(product?.Available_Quantity__c || 0)) return toast('There is not enough stock for that quantity.');
            state.cart.set(id, quantity);
        }
    }
    renderCart();
    scheduleCartSave();
}
$('#cartItems').addEventListener('click', updateCartFromEvent);
$('#cartToggle').addEventListener('click', scrollToBag);
$('#continueShopping').addEventListener('click', () => $('#productGrid').scrollIntoView({ behavior: 'smooth', block: 'start' }));
$('#checkoutOpen').addEventListener('click', startCheckout);
$('#checkoutForm').elements.customerType.addEventListener('change', event => {
    const business = event.currentTarget.value === 'Business';
    const field = $('#businessNameField');
    field.classList.toggle('hidden', !business);
    field.querySelector('input').disabled = !business;
    field.querySelector('input').required = business;
});
$('#customerSignIn').addEventListener('click', () => {
    setError($('#customerEmailError'));
    setError($('#customerCodeError'));
    renderCustomerProfile();
    $('#customerEmailForm').classList.toggle('hidden', Boolean(state.customerProfile));
    $('#customerCodeForm').classList.add('hidden');
    $('#customerLoginModal').showModal();
});
$('#customerEmailForm').addEventListener('submit', async event => {
    event.preventDefault();
    const button = $('#requestCodeButton');
    setError($('#customerEmailError'));
    setBusy(button, true, 'Sending code…');
    try {
        const email = $('#customerLoginEmail').value.trim();
        await api('/api/customer-login/request-code', { method: 'POST', body: JSON.stringify({ email }) });
        $('#customerEmailForm').classList.add('hidden');
        $('#customerCodeForm').classList.remove('hidden');
        $('#customerCodeMessage').textContent = `If ${email} belongs to a customer account, a sign-in code has been emailed. It expires in 10 minutes.`;
        $('#customerLoginCode').focus();
    } catch (error) { setError($('#customerEmailError'), error.message); }
    finally { setBusy(button, false, 'Email me a code'); }
});
$('#customerCodeForm').addEventListener('submit', async event => {
    event.preventDefault();
    const button = $('#verifyCodeButton');
    setError($('#customerCodeError'));
    setBusy(button, true, 'Verifying…');
    try {
        const result = await api('/api/customer-login/verify-code', {
            method: 'POST',
            body: JSON.stringify({ email: $('#customerLoginEmail').value.trim(), code: $('#customerLoginCode').value.trim() })
        });
        applyCustomerProfile(result.profile);
        await restoreCustomerProgress(result.profile);
        $('#customerLoginCode').value = '';
        $('#customerLoginModal').close();
        toast('Signed in. Your saved cart and checkout details are ready.');
    } catch (error) { setError($('#customerCodeError'), error.message); }
    finally { setBusy(button, false, 'Verify & sign in'); }
});
$('#changeLoginEmail').addEventListener('click', () => {
    $('#customerLoginCode').value = '';
    $('#customerCodeForm').classList.add('hidden');
    $('#customerEmailForm').classList.remove('hidden');
    setError($('#customerCodeError'));
});
$('#customerSignOut').addEventListener('click', async () => {
    clearTimeout(customerCartSaveTimer);
    const cart = [...state.cart.entries()].map(([productId, quantity]) => ({ productId, quantity }));
    localStorage.setItem(GUEST_CART_KEY, JSON.stringify(cart));
    try {
        await api('/api/customer-progress', { method: 'PUT', body: JSON.stringify({ cart }) });
        await api('/api/customer-login/logout', { method: 'POST' });
    }
    catch { /* The local profile is cleared even if the server session expired. */ }
    state.customerProfile = null;
    $('#checkoutForm').reset();
    renderCustomerProfile();
    $('#customerLoginModal').close();
    toast('You have signed out.');
});
$('#adminOpen').addEventListener('click', async () => {
    $('#adminKeyInput').value = sessionStorage.getItem('storeAdminKey') || '';
    $('#adminModal').showModal();
    try {
        state.status = await api('/api/status');
        renderConnection();
        if (state.status.connected && $('#adminKeyInput').value) await loadOrderDashboard();
    } catch (error) { setError($('#adminError'), error.message); }
});
$('#refreshOrdersButton').addEventListener('click', loadOrderDashboard);
document.querySelectorAll('[data-close]').forEach(button => button.addEventListener('click', () => $('#' + button.dataset.close).close()));

$('#checkoutForm').addEventListener('submit', async event => {
    event.preventDefault();
    const form = event.currentTarget;
    const button = $('#placeOrderButton');
    const error = $('#checkoutError');
    setError(error);
    const items = [...state.cart].map(([productId, quantity]) => ({ productId, quantity }));
    if (items.length < 1) {
        setError(error, 'Add at least one product to your bag before placing the order.');
        return;
    }
    setBusy(button, true, 'Sending order…');
    try {
        state.requestId = state.requestId || crypto.randomUUID();
        const result = await api('/api/orders', {
            method: 'POST',
            body: JSON.stringify({ clientRequestId: state.requestId, customer: formData(form), items })
        });
        form.reset();
        state.requestId = null;
        state.cart.clear();
        $('#checkoutModal').close();
        renderCart();
        scheduleCartSave();
        showOrderResult(result);
        await refreshCatalog();
    } catch (err) { setError(error, err.message); }
    finally { setBusy(button, false, 'Place order'); }
});

$('#connectSalesforceButton').addEventListener('click', async () => {
    setError($('#adminError'));
    const key = $('#adminKeyInput').value;
    if (!key) return setError($('#adminError'), 'Enter the website admin key first.');
    sessionStorage.setItem('storeAdminKey', key);
    try {
        const result = await api('/api/salesforce/connect', { method: 'POST', headers: { 'x-admin-key': key } });
        location.assign(result.authorizeUrl);
    } catch (error) { setError($('#adminError'), error.message); }
});

$('#disconnectSalesforceButton').addEventListener('click', async () => {
    try {
        const key = $('#adminKeyInput').value;
        await api('/api/salesforce/disconnect', { method: 'POST', headers: { 'x-admin-key': key } });
        sessionStorage.setItem('storeAdminKey', key);
        state.status = await api('/api/status');
        renderConnection();
        await refreshCatalog();
        toast('Salesforce disconnected.');
    } catch (error) { setError($('#adminError'), error.message); }
});

$('#productForm').addEventListener('submit', async event => {
    event.preventDefault();
    const form = event.currentTarget;
    const key = $('#adminKeyInput').value;
    const button = $('#saveProductButton');
    setError($('#productError'));
    setBusy(button, true, 'Saving product…');
    const values = formData(form);
    try {
        await api('/api/admin/products', {
            method: 'POST', headers: { 'x-admin-key': key },
            body: JSON.stringify({ product: { name: values.name, productCode: values.productCode, unitPrice: Number(values.unitPrice), availableQuantity: Number(values.availableQuantity), reorderLevel: Number(values.reorderLevel), description: values.description } })
        });
        sessionStorage.setItem('storeAdminKey', key);
        form.reset();
        await refreshCatalog();
        toast('Product saved to Salesforce.');
    } catch (error) { setError($('#productError'), error.message); }
    finally { setBusy(button, false, 'Save product'); }
});

async function initialize() {
    recordPageView();
    try {
        await refreshCatalog();
        try {
            const session = await api('/api/customer-login/profile');
            if (session.profile) {
                applyCustomerProfile(session.profile);
                await restoreCustomerProgress(session.profile);
            }
        } catch { await restoreGuestCart(); }
        if (new URLSearchParams(location.search).has('connected')) {
            history.replaceState({}, '', '/');
            toast('Salesforce is connected. Live products are loading.');
        }
    } catch (error) {
        $('#catalogStatus').textContent = 'The catalog could not be loaded.';
        toast(error.message);
    }
}

initialize();
