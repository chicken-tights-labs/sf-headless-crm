import { createElement } from "lwc";
import { refreshApex } from "@salesforce/apex";
import Epic03ReplaceCheckInCode from "c/epic03ReplaceCheckInCode";
import currentCode from "@salesforce/apex/EPIC03_CheckInCode_Service.currentCode";
import replaceCode from "@salesforce/apex/EPIC03_CheckInCode_Service.replaceCode";

jest.mock(
  "@salesforce/apex",
  () => ({
    refreshApex: jest.fn(() => Promise.resolve())
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/EPIC03_CheckInCode_Service.currentCode",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/EPIC03_CheckInCode_Service.replaceCode",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

function flushPromises() {
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("c-epic03-replace-check-in-code", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("shows the current code and overwrites it", async () => {
    replaceCode.mockResolvedValue("BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB");
    const element = createElement("c-epic03-replace-check-in-code", {
      is: Epic03ReplaceCheckInCode
    });
    element.recordId = "a0A000000000001";
    document.body.appendChild(element);
    currentCode.emit("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    );

    element.shadowRoot.querySelector("lightning-button").click();
    await flushPromises();

    expect(replaceCode).toHaveBeenCalledWith({
      memberId: "a0A000000000001"
    });
    expect(element.shadowRoot.textContent).toContain(
      "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
    );
    expect(element.shadowRoot.textContent).toContain(
      "The previous code no longer works."
    );
    expect(refreshApex).toHaveBeenCalled();
  });
});
