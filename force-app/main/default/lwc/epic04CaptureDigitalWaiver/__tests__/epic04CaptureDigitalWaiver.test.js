import { createElement } from "lwc";
import Epic04CaptureDigitalWaiver, {
  MSG_DRAW_REQUIRED
} from "c/epic04CaptureDigitalWaiver";
import getCaptureContext from "@salesforce/apex/EPIC04_WaiverCapture_Controller.getCaptureContext";
import captureWaiver from "@salesforce/apex/EPIC04_WaiverCapture_Controller.captureWaiver";

jest.mock(
  "@salesforce/apex/EPIC04_WaiverCapture_Controller.getCaptureContext",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/EPIC04_WaiverCapture_Controller.captureWaiver",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "lightning/actions",
  () => ({
    CloseActionScreenEvent: class CloseActionScreenEvent extends CustomEvent {
      constructor() {
        super("lightning__actionsclosescreen");
      }
    }
  }),
  { virtual: true }
);

jest.mock(
  "lightning/platformShowToastEvent",
  () => ({
    ShowToastEvent: class ShowToastEvent extends CustomEvent {
      constructor(detail) {
        super("lightning__showtoast", { detail });
      }
    }
  }),
  { virtual: true }
);

const CONTEXT = {
  recordType: "Member",
  displayName: "Avery Johnson",
  signerName: "Avery Johnson",
  signerEmail: "avery.johnson@email.com",
  locationId: "a01000000000001AAA",
  locationName: "Lexington HQ",
  defaultTemplateId: "a02000000000001AAA",
  templates: [
    {
      id: "a02000000000001AAA",
      name: "General Liability",
      templateType: "Adult"
    }
  ]
};

function flushPromises() {
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function createPanel(recordId) {
  const element = createElement("c-epic04-capture-digital-waiver", {
    is: Epic04CaptureDigitalWaiver
  });
  element.recordId = recordId;
  document.body.appendChild(element);
  return element;
}

function stubCanvas() {
  HTMLCanvasElement.prototype.getContext = jest.fn(() => ({
    strokeStyle: "",
    lineWidth: 1,
    lineCap: "",
    fillStyle: "",
    beginPath: jest.fn(),
    moveTo: jest.fn(),
    lineTo: jest.fn(),
    stroke: jest.fn(),
    fillRect: jest.fn()
  }));
  HTMLCanvasElement.prototype.toDataURL = jest.fn(
    () => "data:image/png;base64,abc"
  );
}

describe("c-epic04-capture-digital-waiver", () => {
  beforeEach(() => {
    stubCanvas();
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("prefills signer fields from Apex context", async () => {
    const element = createPanel("a03000000000001AAA");
    getCaptureContext.emit(CONTEXT);
    await flushPromises();

    const nameInput = [
      ...element.shadowRoot.querySelectorAll("lightning-input")
    ].find((el) => el.label === "Signer name");
    expect(nameInput.value).toBe("Avery Johnson");
  });

  it("blocks save when the pad has no stroke", async () => {
    const element = createPanel("a03000000000001AAA");
    getCaptureContext.emit(CONTEXT);
    await flushPromises();

    const saveButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((el) => el.label === "Save signed waiver");
    expect(saveButton).toBeTruthy();
    saveButton.click();
    await flushPromises();

    expect(captureWaiver).not.toHaveBeenCalled();
    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert.textContent).toContain(MSG_DRAW_REQUIRED);
  });

  it("shows context error from Apex", async () => {
    const element = createPanel("a03000000000001AAA");
    getCaptureContext.emitError({
      body: {
        message: "No waiver template found. Ask an admin to create one."
      },
      status: 400
    });
    await flushPromises();

    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert.textContent).toContain("No waiver template found");
  });
});
