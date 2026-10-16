import { createElement } from "lwc";
import Epic03SessionAttendees from "c/epic03SessionAttendees";
import getAttendees from "@salesforce/apex/EPIC03_SessionAttendees_Controller.getAttendees";

jest.mock(
  "@salesforce/apex/EPIC03_SessionAttendees_Controller.getAttendees",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

const ROWS = [
  {
    bookingId: "a0B000000000001",
    memberId: "a0A000000000001",
    memberName: "Avery Johnson",
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
});
