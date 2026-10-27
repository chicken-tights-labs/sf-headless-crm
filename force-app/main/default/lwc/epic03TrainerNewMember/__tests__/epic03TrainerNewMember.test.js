import { createElement } from "lwc";
import Epic03TrainerNewMember, {
  MSG_NO_LOCATIONS,
  MSG_LOCATIONS_FAILED,
  MSG_NAME,
  MSG_LOCATION,
  MSG_PROSPECT,
  MSG_LEAD_SAVED,
  MSG_PAYMENT_CLOSED,
  PAYMENT_FLOW
} from "c/epic03TrainerNewMember";
import getActiveLocations from "@salesforce/apex/EPIC04_LeadRegistration_Controller.getActiveLocations";
import createLead from "@salesforce/apex/EPIC04_LeadRegistration_Controller.createLead";
import convertForScreen from "@salesforce/apex/EPIC01_LeadConversion_Action.convertForScreen";

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

jest.mock(
  "@salesforce/apex/EPIC01_LeadConversion_Action.convertForScreen",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const LOCATIONS = [{ Id: "a01000000000001AAA", Name: "NBS Gym - Lexington" }];
const LEAD_ID = "a05000000000001AAA";
const MEMBER_ID = "a06000000000001AAA";

function flushPromises() {
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function createForm() {
  const element = createElement("c-epic03-trainer-new-member", {
    is: Epic03TrainerNewMember
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

function button(element, label) {
  return [...element.shadowRoot.querySelectorAll("lightning-button")].find(
    (el) => el.label === label
  );
}

function errorText(element) {
  return [...element.shadowRoot.querySelectorAll(".slds-text-color_error")].map(
    (p) => p.textContent.trim()
  );
}

function fillVisitor(element) {
  type(element, "First Name", "John");
  type(element, "Last Name", "Smith");
  type(element, "Phone", "5551234567");
  type(element, "Email", "john@example.com");
  type(element, "Franchise Location", LOCATIONS[0].Id);
}

describe("c-epic03-trainer-new-member", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("lists active locations and does not open payment yet", async () => {
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();

    expect(field(element, "Franchise Location").options).toEqual([
      { label: "NBS Gym - Lexington", value: LOCATIONS[0].Id }
    ]);
    expect(element.shadowRoot.querySelector("lightning-flow")).toBeNull();
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

  it("requires a name and a gym before calling Apex", async () => {
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();

    button(element, "New Member").click();
    await flushPromises();
    expect(errorText(element)).toEqual([MSG_NAME]);
    expect(createLead).not.toHaveBeenCalled();

    type(element, "First Name", "John");
    type(element, "Last Name", "Smith");
    button(element, "New Member").click();
    await flushPromises();

    expect(errorText(element)).toEqual([MSG_LOCATION]);
    expect(createLead).not.toHaveBeenCalled();
    expect(convertForScreen).not.toHaveBeenCalled();
  });

  it("creates a walk-in lead and converts it, leaving payment optional", async () => {
    createLead.mockResolvedValue(LEAD_ID);
    convertForScreen.mockResolvedValue({
      success: true,
      message: "Lead converted to Member John_Smith",
      memberId: MEMBER_ID
    });
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();
    fillVisitor(element);

    button(element, "New Member").click();
    await flushPromises();

    expect(createLead).toHaveBeenCalledWith({
      firstName: "John",
      lastName: "Smith",
      phone: "5551234567",
      email: "john@example.com",
      franchiseLocationId: LOCATIONS[0].Id
    });
    expect(convertForScreen).toHaveBeenCalledWith({ leadId: LEAD_ID });
    expect(element.shadowRoot.textContent).toContain(
      "Lead converted to Member John_Smith"
    );
    expect(element.shadowRoot.textContent).toContain(MSG_PROSPECT);
    expect(element.shadowRoot.querySelector("a").href).toContain(
      `/lightning/r/Member__c/${MEMBER_ID}/view`
    );
    expect(element.shadowRoot.querySelector("lightning-flow")).toBeNull();
    expect(field(element, "First Name")).toBeUndefined();
  });

  it("opens the existing payment flow only when Take payment is clicked", async () => {
    createLead.mockResolvedValue(LEAD_ID);
    convertForScreen.mockResolvedValue({
      success: true,
      message: "Lead converted to Member John_Smith",
      memberId: MEMBER_ID
    });
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();
    fillVisitor(element);
    button(element, "New Member").click();
    await flushPromises();

    button(element, "Take payment").click();
    await flushPromises();

    const flow = element.shadowRoot.querySelector("lightning-flow");
    expect(flow.flowApiName).toBe(PAYMENT_FLOW);
    expect(flow.flowInputVariables).toEqual([
      { name: "recordId", type: "String", value: MEMBER_ID }
    ]);

    flow.dispatchEvent(
      new CustomEvent("statuschange", { detail: { status: "FINISHED" } })
    );
    await flushPromises();

    expect(element.shadowRoot.querySelector("lightning-flow")).toBeNull();
    expect(element.shadowRoot.textContent).toContain(MSG_PAYMENT_CLOSED);
  });

  it("keeps the lead and does not open payment when conversion fails", async () => {
    createLead.mockResolvedValue(LEAD_ID);
    convertForScreen.mockResolvedValue({
      success: false,
      message: "Cannot convert: Lead has no Franchise Location assigned"
    });
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();
    fillVisitor(element);

    button(element, "New Member").click();
    await flushPromises();

    expect(errorText(element)[0]).toContain(
      "Cannot convert: Lead has no Franchise Location assigned"
    );
    expect(errorText(element)[0]).toContain(MSG_LEAD_SAVED);
    expect(button(element, "New Member")).toBeUndefined();
    expect(button(element, "Take payment")).toBeUndefined();
    expect(element.shadowRoot.querySelector("a").href).toContain(
      `/lightning/r/Lead__c/${LEAD_ID}/view`
    );
    expect(element.shadowRoot.querySelector("lightning-flow")).toBeNull();

    convertForScreen.mockResolvedValue({
      success: true,
      message: "Lead converted to Member John_Smith",
      memberId: MEMBER_ID
    });
    button(element, "Try convert again").click();
    await flushPromises();

    expect(createLead).toHaveBeenCalledTimes(1);
    expect(convertForScreen).toHaveBeenCalledTimes(2);
    expect(convertForScreen).toHaveBeenLastCalledWith({ leadId: LEAD_ID });
    expect(element.shadowRoot.textContent).toContain(
      "Lead converted to Member John_Smith"
    );
    expect(button(element, "Take payment")).toBeTruthy();
  });

  it("shows the server error and does not convert when the lead is rejected", async () => {
    createLead.mockRejectedValue({ body: { message: "Lead already exists" } });
    const element = createForm();
    getActiveLocations.emit(LOCATIONS);
    await flushPromises();
    fillVisitor(element);

    button(element, "New Member").click();
    await flushPromises();

    expect(convertForScreen).not.toHaveBeenCalled();
    expect(errorText(element)).toEqual(["Lead already exists"]);
  });
});
