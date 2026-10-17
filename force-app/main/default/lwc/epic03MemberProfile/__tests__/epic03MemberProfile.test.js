import { createElement } from "lwc";
import Epic03MemberProfile from "c/epic03MemberProfile";
import getProfile from "@salesforce/apex/EPIC03_MemberProfile_Controller.getProfile";

jest.mock(
  "@salesforce/apex/EPIC03_MemberProfile_Controller.getProfile",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

const PROFILE_WITH_NOTES = {
  memberId: "a0A000000000001",
  name: "Avery Johnson",
  membershipTier: "Monthly Unlimited ($129)",
  status: "Active",
  expiryDate: "2026-11-15",
  canViewMedicalNotes: true,
  medicalNotes: "Asthma — keep inhaler nearby"
};

const PROFILE_NO_NOTES_PERM = {
  memberId: "a0A000000000001",
  name: "Avery Johnson",
  membershipTier: "Monthly Unlimited ($129)",
  status: "Active",
  expiryDate: "2026-11-15",
  canViewMedicalNotes: false,
  medicalNotes: null
};

function flushPromises() {
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function createPanel(recordId) {
  const element = createElement("c-epic03-member-profile", {
    is: Epic03MemberProfile
  });
  element.recordId = recordId;
  document.body.appendChild(element);
  return element;
}

describe("c-epic03-member-profile", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders name, tier, status, expiry, and medical notes when permitted", async () => {
    const element = createPanel("a0A000000000001");
    getProfile.emit(PROFILE_WITH_NOTES);
    await flushPromises();

    const text = element.shadowRoot.textContent;
    expect(text).toContain("Avery Johnson");
    expect(text).toContain("Monthly Unlimited ($129)");
    expect(text).toContain("Active");
    expect(text).toContain("2026-11-15");
    expect(text).toContain("Asthma — keep inhaler nearby");
  });

  it("hides medical notes when permission is false", async () => {
    const element = createPanel("a0A000000000001");
    getProfile.emit(PROFILE_NO_NOTES_PERM);
    await flushPromises();

    const text = element.shadowRoot.textContent;
    expect(text).toContain("Avery Johnson");
    expect(text).not.toContain("Medical notes");
  });

  it("shows wire error", async () => {
    const element = createPanel("a0A000000000001");
    getProfile.error({
      body: { message: "Access denied" },
      status: 403,
      statusText: "Forbidden",
      ok: false
    });
    await flushPromises();

    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert).not.toBeNull();
    expect(alert.textContent).toMatch(/Access denied|Unknown error/);
  });
});
