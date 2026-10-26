import { createElement } from "lwc";
import Epic04ManagerPin from "c/epic04ManagerPin";
import canManagePins from "@salesforce/apex/EPIC04_ManagerPin_Service.canManagePins";
import setMyPin from "@salesforce/apex/EPIC04_ManagerPin_Service.setMyPin";

jest.mock(
  "@salesforce/apex/EPIC04_ManagerPin_Service.canManagePins",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/EPIC04_ManagerPin_Service.setMyPin",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

function flushPromises() {
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function createForm() {
  const element = createElement("c-epic04-manager-pin", {
    is: Epic04ManagerPin
  });
  document.body.appendChild(element);
  return element;
}

describe("c-epic04-manager-pin", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("stays hidden without the manager permission", async () => {
    canManagePins.mockResolvedValue(false);
    const element = createForm();
    await flushPromises();

    expect(element.shadowRoot.querySelector("lightning-card")).toBeNull();
  });

  it("saves a PIN for a manager", async () => {
    canManagePins.mockResolvedValue(true);
    setMyPin.mockResolvedValue(undefined);
    const element = createForm();
    await flushPromises();

    const input = element.shadowRoot.querySelector("lightning-input");
    input.value = "4321";
    input.dispatchEvent(new CustomEvent("change"));
    element.shadowRoot.querySelector("lightning-button").click();
    await flushPromises();

    expect(setMyPin).toHaveBeenCalledWith({ pin: "4321" });
    expect(element.shadowRoot.textContent).toContain("PIN saved.");
  });
});
