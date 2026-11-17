# Smart Order & Inventory Management

Salesforce DX implementation for the AI-Powered Order & Inventory Management mini project. The current org model keeps the existing `Sales_Order__c` API name and adds `Customer__c`, `Product__c`, `Order_Item__c`, and `Invoice__c`.

## Deployed features

- **Order entry:** Open the **Order Entry** tab in the **Sales** Lightning app. The `orderCreator` LWC creates a customer order with multiple products and submits it.
- **Screen flow:** Open **Create Order** in the **Sales** app to select a customer, product, and quantity, then create and submit a single-line order. The flow calls the secured, bulk-safe `OrderCreationFlowAction` Apex action.
- **Monitoring:** The **Inventory Dashboard** tab shows low-stock products and grouped order totals. Its Apex reads run in user mode, so results follow the current user’s access. The **Low Stock Products** and **Orders by Status** reports are also available in Reports.
- **Order visibility:** The **Sales Orders** tab is in the Sales app, with **Active Sales Orders** and **All Sales Orders** list views. Customer pages show their Sales Orders; each Sales Order shows its Order Items and linked Products. Product pages also show their Order Items.
- **Price and totals:** Each order line snapshots the product price when it is created. The order total is calculated by the roll-up field.
- **Inventory:** An approved order is locked and checked against available stock. Stock is deducted once, and an order with insufficient stock is rejected without a deduction.
- **Approval rule:** Orders at or above 100,000 in the org currency remain pending; lower-value orders are approved automatically. A routed Salesforce Approval Process is not yet configured; approval decisions are currently status-based.
- **Permissions:** `Smart_Order_Inventory_Access` grants read/create/edit access to the application records and no delete access.
- **External sync:** Queueable Apex posts processed orders to a Salesforce Named Credential endpoint and records failures. A successful response can create a linked invoice.
- **Assistant actions:** `OrderAssistantLookupAction` provides read-only product stock, pending approval, order detail, and invoice sync lookups. `OrderCreationFlowAction` creates a customer order. Both invocable actions are registered for Flow and can be added to an Agentforce agent when that feature is enabled.

## Enable external order sync

Sync is **off by default**. Before enabling it:

1. Create a Salesforce Named Credential for the external REST service.
2. Make its base URL accept `POST /orders`. The request includes an `Idempotency-Key` header based on the Salesforce order ID and a JSON body with order, customer name, and line items.
3. Configure the service to honor that idempotency key. It should return a 2xx JSON response containing `externalOrderId` or `orderReference`; optionally include `externalInvoiceId` or `invoiceId` to create an `Invoice__c` record.
4. Set `Order_Sync_Settings__mdt.Default.Enabled` to true and `Named_Credential` to the Named Credential API name.

The included configuration names `OrderSyncMock` as a placeholder but does not create a Named Credential or contact an external service. Until configured and enabled, processed orders remain unsynced and no order data is sent outside Salesforce. Failed HTTP responses are stored in `Sales_Order__c.Sync_Error__c` and do not mark the order as synced.

## Run the storefront

The standalone storefront is in [`website/`](website/). It has a product catalog, search, cart, customer checkout, Salesforce OAuth connection, a store admin form for adding products, and an admin-key-protected dashboard of recent Salesforce orders and active-order totals. The Node server keeps OAuth tokens and secrets off the browser and listens on `127.0.0.1` by default.

1. Install Node.js 20 or newer.
2. From `website`, copy `.env.example` to `.env` and set `SITE_ADMIN_KEY` and `WEBSITE_ID_SECRET` to separate long random values. Set `STORE_CURRENCY` to the Salesforce org currency (the sample defaults to `INR`).
3. The connected org now has a local External Client App named `Smart_Order_Inventory_Website` with API and refresh-token scopes, PKCE required, and a 30-day refresh-token lifetime. For this local development site, its client ID is in `website/.env`. The client secret is optional under this app’s current OAuth policy. For a sandbox, set `SF_LOGIN_URL=https://test.salesforce.com`.
4. Deploy the five website external-ID fields, `WebsiteCustomerLoginMailer`, and the permission-set access from this project. Assign `Smart_Order_Inventory_Access` to the Salesforce user who authorizes the website; the ECA preauthorizes only users with this permission set.
5. Run `npm start` from `website`, then open `http://localhost:4173`. In **Store admin**, enter `SITE_ADMIN_KEY` and choose **Connect Salesforce**.

Returning customers can select **Sign in** in the storefront and verify access with a one-time email code. Salesforce sends the code to the email on their `Customer__c` record. The website only returns saved customer fields after code verification. Configure Salesforce email deliverability before using this in a live store. Store admins can open **Store admin** and refresh the **Order dashboard** after entering the website admin key.

Until OAuth is configured, the site shows a clearly marked preview from `product-seed.csv`; it cannot submit live orders. After connection, it reads and writes the project's custom `Product__c`, `Customer__c`, `Sales_Order__c`, and `Order_Item__c` objects. The standard Salesforce **Products** page is backed by `Product2`, so this website's custom catalog will not appear there without a separate `Product2` mapping. The Salesforce-to-external order sync described above is a separate feature and remains off until an external endpoint is configured.

The storefront can run locally for demonstration. On checkout, every customer is saved to `Customer__c` and synced to a Salesforce Contact. Business customers also get a Salesforce Account, and the Contact is linked to it. Business Account upserts use a private HMAC-derived external ID to avoid creating duplicates on order retries. Deploy the Account field `Website_Business_ID__c`, the Customer field `Business_Name__c`, and the updated `Smart_Order_Inventory_Access` permission set; grant the connected Salesforce user create/read/edit access to Account and Contact and the listed standard fields. Before exposing the site publicly, host it behind HTTPS, use a production Salesforce callback URL, and keep `.env` private.

## Smart Order AI Assistant

The repository includes the Node.js assistant integration and the Salesforce read-only lookup layer. The storefront chat routes to Gemini when Salesforce is connected; Gemini can call product/stock and order lookup functions, and the server executes those calls against Salesforce. If Gemini is not configured, the storefront falls back to the existing product lookup assistant. Order tracking requires a customer to sign in through the one-time email code flow. The server passes the verified email to Apex, which restricts the order query to that customer; pending-approval listings are intentionally not exposed in public chat.

### Configure and deploy

1. In `website/.env`, set `GEMINI_API_KEY` and optionally `GEMINI_MODEL` (default `gemini-2.0-flash`). Keep both on the server; never add them to browser code. Keep `WEBSITE_ID_SECRET`, `SITE_ADMIN_KEY`, and Salesforce OAuth credentials private as well. The checked-in `.env.example` documents the variables; do not commit `.env`.
2. Configure Salesforce External Client App OAuth and the callback URL in `SF_CALLBACK_URL`. The connected user must have API access, access to the custom objects and queried fields, and Apex class access for `AssistantLookupRestController` and `WebsiteCustomerLoginMailer`. The Apex lookup uses user-mode queries, so Salesforce object, field, and record access still apply.
3. Deploy `AssistantLookupRestController`, `OrderAssistantLookupAction`, and the website customer-login Apex class with this Salesforce DX project. Ensure `Smart_Order_Inventory_Access` (or an equivalent least-privilege permission set) grants the connected principal the required read access. Verify `/services/apexrest/assistant/lookup` is reachable using that OAuth connection.
4. Start the website and connect Salesforce from Store admin. Confirm customer email deliverability is enabled before exercising order tracking, because customer verification depends on the one-time email code.

The Apex endpoint supports `CHECK_STOCK`, `ORDER_DETAILS`, `PENDING_APPROVALS`, and `INVOICE_STATUS`; the public Gemini tool set only offers product/stock and customer-restricted order lookups. The older `/api/assistant/query` endpoint remains as a non-Gemini product lookup fallback.

### Agentforce customer assistant

The customer-agent scope is recorded in [`specs/fieldFormStoreAgent.yaml`](specs/fieldFormStoreAgent.yaml): product discovery, storefront guidance, and verified order help. The active Agent Script bundle is [`Field_Form_Store_Agent.agent`](force-app/main/default/aiAuthoringBundles/Field_Form_Store_Agent/Field_Form_Store_Agent.agent). It includes a read-only `AgentforceProductLookupAction` that searches active `Product__c` records using user-mode SOQL and returns current price, stock, and description. The dedicated `Agentforce_Product_Assistant` permission set grants only Product read access and access to that Apex action; it is assigned to the org’s Einstein Agent User.

The agent was published as version 1 and activated in the newly connected Developer Edition org (`aforg`, API 68). The org already has an enabled Embedded Messaging web deployment, but its `ESA_Channel` currently uses the active `Route_to_ESA` flow, which routes sessions to `Messaging Queue`. It is not connected to `Field_Form_Store_Agent`, and the standalone Node storefront does not yet embed that Salesforce deployment. Connect the service agent to a dedicated inbound messaging route/channel and install the generated deployment snippet on the intended site before customers can reach it. Keep order lookup unavailable in this agent until a trusted Salesforce Messaging identity signal is wired through; a customer-provided email or code is not proof of sign-in. See Salesforce’s [Agentforce enablement guide](https://help.salesforce.com/s/articleView?id=ai.copilot_setup_enable.htm&language=en_US&type=5) and [customer-support identity example](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-examples-customer-support.html).

### Salesforce Enhanced Chat handoff

The connected org has an Embedded Messaging channel and web deployment. Its current route sends sessions to a Salesforce queue; it has not been repointed to this customer assistant. The Node website chat remains connected to `/api/chat`. Do not expose the Gemini key or Salesforce OAuth token to the browser. The storefront's customer sign-in cookie is scoped to that website and must not be treated as Salesforce Messaging identity; pass a trusted, verified customer identity from Salesforce before enabling order lookup in a Messaging channel.

## Apex tests

- `InventoryProcessingServiceTest` covers price snapshots, approvals, inventory deduction, stock rejection, and LWC order creation.
- `OrderSyncQueueableTest` covers a successful mocked response, invoice creation, external failure handling, and sync configuration behavior.
- `OrderInventoryDashboardControllerTest` covers low-stock and grouped order metrics.
- `OrderAssistantLookupActionTest` covers all four assistant lookup types.
- `OrderCreationFlowActionTest` covers bulk order creation and rejection of inactive products.

The latest order creation action deployment succeeded with both selected Apex tests passing. The screen flow and Sales app tab also deployed successfully.

## Known implementation gaps

- Approval is currently a status-based manual decision; a routed Salesforce Approval Process and decision email notifications are not yet configured. Deployment of the ApprovalProcess metadata returned a Salesforce internal `UNKNOWN_EXCEPTION`, including for a minimal validation payload.
- The high-value threshold is currently a constant (`100000`) and assumes the org currency.
- The active Field & Form Agentforce service agent is not yet routed from the existing Embedded Messaging channel or embedded in the standalone storefront. Verified order lookup is intentionally unavailable until a trusted channel identity is connected.
- The Create Order screen flow supports one product per order run; the Order Entry LWC supports multiple products. Approval-decision notifications are not configured yet.
- External sync requires a user-provided endpoint and Named Credential before it can run.
- The inventory dashboard is a permission-restricted Lightning page. A public Salesforce Dashboard folder was rejected by automatic access review because it would make the dashboard available across the org.
