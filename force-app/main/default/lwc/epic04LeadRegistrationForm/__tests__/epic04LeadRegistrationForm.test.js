import { createElement } from "lwc";
import Epic04LeadRegistrationForm, {
  MSG_NO_LOCATIONS,
  MSG_LOCATIONS_FAILED
} from "c/epic04LeadRegistrationForm";
import getActiveLocations from "@salesforce/apex/EPIC04_LeadRegistration_Controller.getActiveLocations";
import createLead from "@salesforce/apex/EPIC04_LeadRegistration_Controller.createLead";

jest.mock(
  "@salesforce/apex/EPIC04_LeadRegistration_Controller.getActiveLocations",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/EPIC04_LeadRegistration_Controller.createLead",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const LOCATIONS = [
  { Id: "a01000000000001AAA", Name: "NBS Gym - Ashland" },
  { Id: "a01000000000002AAA", Name: "NBS Gym - Lexington" }
];

function flushPromises() {
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function createForm() {
  const element = createElement("c-epic04-lead-registration-form", {
    is: Epic04LeadRegistrationForm
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
  el.dispatchEvent(new CustomEvent("change", { detail: { value } }));
}

function errorText(element) {
  return [...element.shadowRoot.querySelectorAll(".slds-text-color_error")].map(
    (p) => p.textContent
  );
}

describe("c-epic04-lead-registration-form", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("lists active locations by name in the Franchise Location picker", async () => {
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();

    expect(field(element, "Franchise Location").options).toEqual([
      { label: "NBS Gym - Ashland", value: "a01000000000001AAA" },
      { label: "NBS Gym - Lexington", value: "a01000000000002AAA" }
    ]);
    expect(errorText(element)).toEqual([]);
  });

  it("explains when there are no active locations", async () => {
    const element = createForm();
    getActiveLocations.emit([]);
    await flushPromises();

    expect(errorText(element)).toEqual([MSG_NO_LOCATIONS]);
  });

  it("explains when locations fail to load", async () => {
    const element = createForm();
    getActiveLocations.error();
    await flushPromises();

    expect(errorText(element)).toEqual([MSG_LOCATIONS_FAILED]);
  });

  it("sends the picked location Id and clears visitor fields after success", async () => {
    createLead.mockResolvedValue("a05000000000001AAA");
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();

    type(element, "First Name", "John");
    type(element, "Last Name", "Smith");
    type(element, "Phone", "5551234567");
    type(element, "Email", "john@example.com");
    type(element, "Franchise Location", "a01000000000002AAA");

    element.shadowRoot.querySelector("lightning-button").click();
    await flushPromises();

    expect(createLead).toHaveBeenCalledWith({
      firstName: "John",
      lastName: "Smith",
      phone: "5551234567",
      email: "john@example.com",
      franchiseLocationId: "a01000000000002AAA"
    });
    expect(
      element.shadowRoot.querySelector(".slds-text-heading_small").textContent
    ).toBe("Lead registered successfully! Lead ID: a05000000000001AAA");
    expect(field(element, "First Name").value).toBe("");
    expect(field(element, "Email").value).toBe("");
    expect(field(element, "Franchise Location").value).toBe(
      "a01000000000002AAA"
    );
  });

  it("shows the server error when the lead is rejected", async () => {
    createLead.mockRejectedValue({ body: { message: "Lead already exists" } });
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();

    element.shadowRoot.querySelector("lightning-button").click();
    await flushPromises();

    expect(errorText(element)).toEqual(["Lead already exists"]);
  });
});
