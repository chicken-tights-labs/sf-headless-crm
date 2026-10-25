import { createElement } from "lwc";
import Epic03SessionAttendees from "c/epic03SessionAttendees";
import getAttendees from "@salesforce/apex/EPIC03_SessionAttendees_Controller.getAttendees";
import findByPhone from "@salesforce/apex/EPIC03_SessionAttendees_Controller.findByPhone";
import markAttended from "@salesforce/apex/EPIC03_SessionAttendees_Controller.markAttended";

jest.mock(
  "@salesforce/apex/EPIC03_SessionAttendees_Controller.getAttendees",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/EPIC03_SessionAttendees_Controller.findByPhone",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/EPIC03_SessionAttendees_Controller.markAttended",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex",
  () => ({
    refreshApex: jest.fn(() => Promise.resolve())
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

const ROWS = [
  {
    bookingId: "a0B000000000001",
    memberId: "a0A000000000001",
    memberName: "Avery Johnson",
    memberUrl: "/a0A000000000001",
    bookingStatus: "Confirmed",
    checkInStatus: "Not checked in",
    waiverStatus: "Signed"
  }
];

function flushPromises() {
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function createPanel(recordId) {
  const element = createElement("c-epic03-session-attendees", {
    is: Epic03SessionAttendees
  });
  element.recordId = recordId;
  document.body.appendChild(element);
  return element;
}

describe("c-epic03-session-attendees", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders attendee rows from Apex", async () => {
    const element = createPanel("a0C000000000001");
    getAttendees.emit(ROWS);
    await flushPromises();

    const table = element.shadowRoot.querySelector("lightning-datatable");
    expect(table).not.toBeNull();
    expect(table.data).toHaveLength(1);
    expect(table.data[0].memberName).toBe("Avery Johnson");
    expect(element.shadowRoot.textContent).toContain("1 attendee");
  });

  it("shows empty state when there are no bookings", async () => {
    const element = createPanel("a0C000000000001");
    getAttendees.emit([]);
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "No bookings for this session yet."
    );
    expect(element.shadowRoot.querySelector("lightning-datatable")).toBeNull();
  });

  it("shows an error from Apex", async () => {
    const element = createPanel("a0C000000000001");
    getAttendees.emitError({
      body: { message: "Read failed" },
      status: 400
    });
    await flushPromises();

    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert.textContent).toContain("Read failed");
  });

  it("calls markAttended on row action and shows waiver block message", async () => {
    markAttended.mockResolvedValue({
      success: false,
      message: "Cannot check in - member does not have a valid signed waiver"
    });

    const element = createPanel("a0C000000000001");
    getAttendees.emit(ROWS);
    await flushPromises();

    const table = element.shadowRoot.querySelector("lightning-datatable");
    table.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: {
          action: { name: "mark_attended" },
          row: ROWS[0]
        }
      })
    );
    await flushPromises();

    expect(markAttended).toHaveBeenCalledWith({ bookingId: ROWS[0].bookingId });
    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert.textContent).toContain(
      "Cannot check in - member does not have a valid signed waiver"
    );
  });

  it("finds a member by phone and confirms with markAttended", async () => {
    findByPhone.mockResolvedValue({
      validInput: true,
      matches: [
        {
          bookingId: "a0B000000000009",
          memberId: "a0A000000000009",
          memberName: "Sam Walker"
        }
      ]
    });
    markAttended.mockResolvedValue({
      success: true,
      message: "Checked in"
    });

    const element = createPanel("a0C000000000001");
    getAttendees.emit(ROWS);
    await flushPromises();

    const phone = element.shadowRoot.querySelector("lightning-input");
    phone.value = "3365550100";
    phone.dispatchEvent(new CustomEvent("change"));

    const findButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((el) => el.label === "Find");
    findButton.click();
    await flushPromises();

    expect(findByPhone).toHaveBeenCalledWith({
      sessionId: "a0C000000000001",
      phone: "3365550100"
    });
    expect(element.shadowRoot.textContent).toContain("Sam Walker");

    const confirmButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((el) => el.label === "Confirm check-in");
    confirmButton.click();
    await flushPromises();

    expect(markAttended).toHaveBeenCalledWith({
      bookingId: "a0B000000000009"
    });
  });
});
