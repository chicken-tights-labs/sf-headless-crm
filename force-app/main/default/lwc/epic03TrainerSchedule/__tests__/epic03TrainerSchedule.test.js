import { createElement } from "lwc";
import Epic03TrainerSchedule from "c/epic03TrainerSchedule";
import getMyWeekSessions from "@salesforce/apex/EPIC03_TrainerSchedule_Controller.getMyWeekSessions";

jest.mock(
  "@salesforce/apex/EPIC03_TrainerSchedule_Controller.getMyWeekSessions",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

const ROWS = [
  {
    sessionId: "a0C000000000001",
    sessionName: "Boxing Fundamentals",
    sessionUrl: "/a0C000000000001",
    startTime: "2026-10-27T14:00:00.000Z",
    endTime: "2026-10-27T15:00:00.000Z",
    locationName: "Lexington HQ",
    bookedCount: 8,
    capacity: 20
  }
];

function flushPromises() {
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function createPanel() {
  const element = createElement("c-epic03-trainer-schedule", {
    is: Epic03TrainerSchedule
  });
  document.body.appendChild(element);
  return element;
}

describe("c-epic03-trainer-schedule", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders this week sessions from Apex", async () => {
    const element = createPanel();
    getMyWeekSessions.emit(ROWS);
    await flushPromises();

    const table = element.shadowRoot.querySelector("lightning-datatable");
    expect(table).not.toBeNull();
    expect(table.data).toHaveLength(1);
    expect(table.data[0].sessionName).toBe("Boxing Fundamentals");
    expect(element.shadowRoot.textContent).toContain("1 class this week");
  });

  it("shows empty state when there are no assigned classes", async () => {
    const element = createPanel();
    getMyWeekSessions.emit([]);
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "No classes assigned to you this week."
    );
    expect(element.shadowRoot.querySelector("lightning-datatable")).toBeNull();
  });

  it("shows an error from Apex", async () => {
    const element = createPanel();
    getMyWeekSessions.emitError({
      body: { message: "Read failed" },
      status: 400
    });
    await flushPromises();

    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert.textContent).toContain("Read failed");
  });
});
