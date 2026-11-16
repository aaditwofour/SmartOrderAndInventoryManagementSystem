import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getLowStockProducts from '@salesforce/apex/OrderInventoryDashboardController.getLowStockProducts';
import getOrderStatusSummary from '@salesforce/apex/OrderInventoryDashboardController.getOrderStatusSummary';

const PRODUCT_COLUMNS = [
    { label: 'Product', fieldName: 'name' },
    { label: 'Code', fieldName: 'productCode' },
    { label: 'Available', fieldName: 'availableQuantity', type: 'number' },
    { label: 'Reorder At', fieldName: 'reorderLevel', type: 'number' }
];

const ORDER_COLUMNS = [
    { label: 'Status', fieldName: 'status' },
    { label: 'Orders', fieldName: 'orderCount', type: 'number' },
    { label: 'Total Value', fieldName: 'orderTotal', type: 'currency' }
];

export default class InventoryDashboard extends LightningElement {
    productColumns = PRODUCT_COLUMNS;
    orderColumns = ORDER_COLUMNS;
    lowStockProducts;
    orderStatusSummary;
    lowStockError;
    orderStatusError;
    lowStockWire;
    orderStatusWire;

    @wire(getLowStockProducts)
    wiredLowStock(result) {
        this.lowStockWire = result;
        if (result.data) {
            this.lowStockProducts = result.data;
            this.lowStockError = undefined;
        } else if (result.error) {
            this.lowStockProducts = undefined;
            this.lowStockError = result.error?.body?.message || 'Low-stock data could not be loaded.';
        }
    }

    @wire(getOrderStatusSummary)
    wiredOrderStatus(result) {
        this.orderStatusWire = result;
        if (result.data) {
            this.orderStatusSummary = result.data;
            this.orderStatusError = undefined;
        } else if (result.error) {
            this.orderStatusSummary = undefined;
            this.orderStatusError = result.error?.body?.message || 'Order status data could not be loaded.';
        }
    }

    get isLoading() {
        return !this.lowStockWire || !this.orderStatusWire;
    }

    get hasLowStockProducts() {
        return Boolean(this.lowStockProducts?.length);
    }

    get hasOrderStatuses() {
        return Boolean(this.orderStatusSummary?.length);
    }

    async handleRefresh() {
        await Promise.all([
            this.lowStockWire && refreshApex(this.lowStockWire),
            this.orderStatusWire && refreshApex(this.orderStatusWire)
        ]);
    }
}
