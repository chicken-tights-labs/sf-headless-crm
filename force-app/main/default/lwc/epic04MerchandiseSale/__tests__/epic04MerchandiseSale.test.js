import { createElement } from "lwc";
import Epic04MerchandiseSale, {
  MSG_NO_LOCATIONS,
  MSG_LOCATIONS_FAILED,
  MSG_NO_STOCK,
  MSG_OVER_STOCK
} from "c/epic04MerchandiseSale";
import getActiveLocations from "@salesforce/apex/EPIC04_MerchandiseSale_Controller.getActiveLocations";
import getSellableInventory from "@salesforce/apex/EPIC04_MerchandiseSale_Controller.getSellableInventory";
import searchMembers from "@salesforce/apex/EPIC04_MerchandiseSale_Controller.searchMembers";
import completeSale from "@salesforce/apex/EPIC04_MerchandiseSale_Controller.completeSale";

jest.mock(
  "@salesforce/apex/EPIC04_MerchandiseSale_Controller.getActiveLocations",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/EPIC04_MerchandiseSale_Controller.getSellableInventory",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/EPIC04_MerchandiseSale_Controller.searchMembers",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/EPIC04_MerchandiseSale_Controller.completeSale",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const LOCATIONS = [{ Id: "a01000000000001AAA", Name: "NBS Gym - Lexington" }];
const GLOVES = {
  Id: "a02000000000001AAA",
  Name: "Gloves",
  SKU__c: "GLV",
  Unit_Price__c: 40,
  Current_Stock__c: 5
};

function flushPromises() {
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function createForm() {
  const element = createElement("c-epic04-merchandise-sale", {
    is: Epic04MerchandiseSale
  });
  document.body.appendChild(element);
  return element;
}

function field(element, label) {
  return [
    ...element.shadowRoot.querySelectorAll(
      "lightning-input, lightning-combobox"
    )
  ].find((el) => el.label === label);
}

function type(element, label, value) {
  const el = field(element, label);
  el.value = value;
  el.dispatchEvent(
    new CustomEvent("change", { detail: { value }, target: { value } })
  );
}

function button(element, label) {
  return [...element.shadowRoot.querySelectorAll("lightning-button")].find(
    (el) => el.label === label
  );
}

describe("c-epic04-merchandise-sale", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("lists active gyms", async () => {
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();

    expect(field(element, "Gym").options).toEqual([
      { label: "NBS Gym - Lexington", value: "a01000000000001AAA" }
    ]);
  });

  it("explains when there are no active gyms", async () => {
    const element = createForm();
    getActiveLocations.emit([]);
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(MSG_NO_LOCATIONS);
  });

  it("explains when gyms fail to load", async () => {
    const element = createForm();
    getActiveLocations.error();
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(MSG_LOCATIONS_FAILED);
  });

  it("shows in-stock items after a gym is chosen", async () => {
    getSellableInventory.mockResolvedValue([GLOVES]);
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();

    type(element, "Gym", LOCATIONS[0].Id);
    await flushPromises();

    expect(getSellableInventory).toHaveBeenCalledWith({
      franchiseLocationId: LOCATIONS[0].Id
    });
    expect(field(element, "Item").options[0].value).toBe(GLOVES.Id);
    expect(field(element, "Item").options[0].label).toContain("Gloves");
    expect(field(element, "Item").options[0].label).toContain("$40.00");
  });

  it("says when the gym has nothing to sell", async () => {
    getSellableInventory.mockResolvedValue([]);
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();

    type(element, "Gym", LOCATIONS[0].Id);
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(MSG_NO_STOCK);
  });

  it("adds a line and sends the cart when the sale completes", async () => {
    getSellableInventory.mockResolvedValue([GLOVES]);
    searchMembers.mockResolvedValue([
      {
        Id: "a03000000000001AAA",
        First_Name__c: "Avery",
        Last_Name__c: "Johnson"
      }
    ]);
    completeSale.mockResolvedValue({
      saleId: "a04000000000001AAA",
      paymentId: "a05000000000001AAA",
      totalAmount: 80
    });
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();

    type(element, "Gym", LOCATIONS[0].Id);
    await flushPromises();
    type(element, "Find member", "Jo");
    await flushPromises();
    type(element, "Member", "a03000000000001AAA");
    type(element, "Item", GLOVES.Id);
    type(element, "Quantity", "2");
    type(element, "Payment method", "Card");
    button(element, "Add to cart").click();
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Cart total $80.00");
    button(element, "Complete sale").click();
    await flushPromises();

    expect(completeSale).toHaveBeenCalledWith({
      memberId: "a03000000000001AAA",
      franchiseLocationId: LOCATIONS[0].Id,
      paymentMethod: "Card",
      lines: [{ inventoryItemId: GLOVES.Id, quantity: 2 }],
      discountPercent: null,
      promoCode: null,
      managerPin: null
    });
    expect(element.shadowRoot.textContent).toContain(
      "Sale completed. Total $80.00."
    );
  });

  it("asks for a manager PIN when the discount is above 10 percent", async () => {
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();

    type(element, "Discount %", "10");
    await flushPromises();
    expect(field(element, "Manager PIN")).toBeUndefined();
    expect(element.shadowRoot.textContent).toContain("Amount due");

    type(element, "Discount %", "15");
    await flushPromises();
    expect(field(element, "Manager PIN")).toBeTruthy();
  });

  it("blocks a quantity above the stock on hand", async () => {
    getSellableInventory.mockResolvedValue([GLOVES]);
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();

    type(element, "Gym", LOCATIONS[0].Id);
    await flushPromises();
    type(element, "Item", GLOVES.Id);
    type(element, "Quantity", "9");
    button(element, "Add to cart").click();
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(MSG_OVER_STOCK);
    expect(completeSale).not.toHaveBeenCalled();
  });

  it("shows the server error when the sale is rejected", async () => {
    getSellableInventory.mockResolvedValue([GLOVES]);
    completeSale.mockRejectedValue({
      body: { message: "Not enough stock for Gloves" }
    });
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();

    type(element, "Gym", LOCATIONS[0].Id);
    await flushPromises();
    type(element, "Member", "a03000000000001AAA");
    type(element, "Item", GLOVES.Id);
    type(element, "Quantity", "1");
    type(element, "Payment method", "Cash");
    button(element, "Add to cart").click();
    await flushPromises();
    button(element, "Complete sale").click();
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "Not enough stock for Gloves"
    );
  });
});
