import { LightningElement, track, wire } from "lwc";
import getActiveLocations from "@salesforce/apex/EPIC04_MerchandiseSale_Controller.getActiveLocations";
import getSellableInventory from "@salesforce/apex/EPIC04_MerchandiseSale_Controller.getSellableInventory";
import searchMembers from "@salesforce/apex/EPIC04_MerchandiseSale_Controller.searchMembers";
import completeSale from "@salesforce/apex/EPIC04_MerchandiseSale_Controller.completeSale";

export const MSG_NO_LOCATIONS =
  "No active gym locations found. Ask an admin to add one.";
export const MSG_LOCATIONS_FAILED =
  "Could not load gym locations. Refresh the page and try again.";
export const MSG_NO_STOCK = "No active items are in stock at this gym.";
export const MSG_QTY = "Quantity must be a whole number greater than zero.";
export const MSG_OVER_STOCK = "Quantity is higher than the stock on hand.";

const PAYMENT_METHODS = ["Cash", "Card", "Account Credit", "Gift Card"];

function money(amount) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD"
  }).format(amount || 0);
}

export default class Epic04MerchandiseSale extends LightningElement {
  @track franchiseLocationId = "";
  @track locationOptions = [];
  @track locationsError;
  @track inventory = [];
  @track inventoryItemId = "";
  @track quantity = 1;
  @track cartLines = [];
  @track memberTerm = "";
  @track memberOptions = [];
  @track memberId = "";
  @track paymentMethod = "";
  @track discountPercent = "";
  @track promoCode = "";
  @track managerPin = "";
  @track message = "";
  @track error;
  @track saving = false;

  paymentMethodOptions = PAYMENT_METHODS.map((method) => ({
    label: method,
    value: method
  }));

  @wire(getActiveLocations)
  wiredLocations({ data, error }) {
    if (data) {
      this.locationOptions = data.map((location) => ({
        label: location.Name,
        value: location.Id
      }));
      this.locationsError = data.length ? undefined : MSG_NO_LOCATIONS;
    } else if (error) {
      this.locationOptions = [];
      this.locationsError = MSG_LOCATIONS_FAILED;
    }
  }

  get inventoryOptions() {
    return this.inventory.map((item) => ({
      label: `${item.Name} (${item.SKU__c}) — ${money(item.Unit_Price__c)} · ${item.Current_Stock__c} in stock`,
      value: item.Id
    }));
  }

  get inventoryMessage() {
    if (this.franchiseLocationId && this.inventory.length === 0) {
      return MSG_NO_STOCK;
    }
    return undefined;
  }

  get shelfTotal() {
    return this.cartLines.reduce((sum, line) => sum + line.lineTotal, 0);
  }

  get cartTotalLabel() {
    return money(this.shelfTotal);
  }

  get discountPercentNumber() {
    const percent = Number(this.discountPercent);
    if (!this.discountPercent || !Number.isInteger(percent) || percent <= 0) {
      return 0;
    }
    return percent;
  }

  get amountDueLabel() {
    const due = this.shelfTotal * (1 - this.discountPercentNumber / 100);
    return money(due);
  }

  get showAmountDue() {
    return this.discountPercentNumber > 0;
  }

  get pinRequired() {
    return this.discountPercentNumber > 10;
  }

  get hasCart() {
    return this.cartLines.length > 0;
  }

  get completeDisabled() {
    return (
      this.saving ||
      !this.memberId ||
      !this.franchiseLocationId ||
      !this.paymentMethod ||
      !this.hasCart
    );
  }

  handleLocationChange(event) {
    this.franchiseLocationId = event.detail.value;
    this.inventoryItemId = "";
    this.cartLines = [];
    this.message = "";
    this.error = undefined;
    this.loadInventory();
  }

  handleMemberTermChange(event) {
    this.memberTerm = event.target.value;
    this.memberId = "";
    if (!this.memberTerm || this.memberTerm.trim().length < 2) {
      this.memberOptions = [];
      return;
    }
    searchMembers({ term: this.memberTerm })
      .then((rows) => {
        this.memberOptions = rows.map((member) => ({
          label: `${member.First_Name__c} ${member.Last_Name__c}`,
          value: member.Id
        }));
      })
      .catch((err) => {
        this.memberOptions = [];
        this.error = this.readError(err);
      });
  }

  handleMemberChange(event) {
    this.memberId = event.detail.value;
  }

  handleItemChange(event) {
    this.inventoryItemId = event.detail.value;
  }

  handleQuantityChange(event) {
    this.quantity = event.target.value;
  }

  handlePaymentChange(event) {
    this.paymentMethod = event.detail.value;
  }

  handleDiscountChange(event) {
    this.discountPercent = event.target.value;
    if (!this.pinRequired) {
      this.managerPin = "";
    }
  }

  handlePromoChange(event) {
    this.promoCode = event.target.value;
  }

  handlePinChange(event) {
    this.managerPin = event.target.value;
  }

  handleAdd() {
    this.error = undefined;
    this.message = "";
    const item = this.inventory.find((row) => row.Id === this.inventoryItemId);
    const qty = Number(this.quantity);
    if (!item || !Number.isInteger(qty) || qty <= 0) {
      this.error = MSG_QTY;
      return;
    }
    const existing = this.cartLines.find(
      (line) => line.inventoryItemId === item.Id
    );
    const nextQty = (existing ? existing.quantity : 0) + qty;
    if (nextQty > item.Current_Stock__c) {
      this.error = MSG_OVER_STOCK;
      return;
    }
    const line = {
      inventoryItemId: item.Id,
      name: item.Name,
      quantity: nextQty,
      unitPriceLabel: money(item.Unit_Price__c),
      lineTotal: item.Unit_Price__c * nextQty,
      lineTotalLabel: money(item.Unit_Price__c * nextQty)
    };
    if (existing) {
      this.cartLines = this.cartLines.map((row) => {
        return row.inventoryItemId === item.Id ? line : row;
      });
    } else {
      this.cartLines = [...this.cartLines, line];
    }
  }

  handleRemove(event) {
    const itemId = event.currentTarget.dataset.id;
    this.cartLines = this.cartLines.filter(
      (line) => line.inventoryItemId !== itemId
    );
  }

  handleComplete() {
    this.error = undefined;
    this.message = "";
    this.saving = true;
    completeSale({
      memberId: this.memberId,
      franchiseLocationId: this.franchiseLocationId,
      paymentMethod: this.paymentMethod,
      lines: this.cartLines.map((line) => ({
        inventoryItemId: line.inventoryItemId,
        quantity: line.quantity
      })),
      discountPercent: this.discountPercentNumber || null,
      promoCode: this.promoCode ? this.promoCode.trim() : null,
      managerPin: this.pinRequired ? this.managerPin : null
    })
      .then((result) => {
        this.message = `Sale completed. Total ${money(result.totalAmount)}.`;
        this.cartLines = [];
        this.inventoryItemId = "";
        this.quantity = 1;
        this.memberId = "";
        this.memberTerm = "";
        this.memberOptions = [];
        this.paymentMethod = "";
        this.discountPercent = "";
        this.promoCode = "";
        this.managerPin = "";
        return this.loadInventory();
      })
      .catch((err) => {
        this.error = this.readError(err);
      })
      .finally(() => {
        this.saving = false;
      });
  }

  loadInventory() {
    if (!this.franchiseLocationId) {
      this.inventory = [];
      return Promise.resolve();
    }
    return getSellableInventory({
      franchiseLocationId: this.franchiseLocationId
    })
      .then((rows) => {
        this.inventory = rows;
      })
      .catch((err) => {
        this.inventory = [];
        this.error = this.readError(err);
      });
  }

  readError(err) {
    if (err && err.body && err.body.message) {
      return err.body.message;
    }
    return "Could not complete the sale. Try again.";
  }
}
