import { createElement } from "@lwc/engine-dom";
import JtQueryViewer from "c/jtQueryViewer";
import assessQueryRisk from "@salesforce/apex/JT_QueryViewerController.assessQueryRisk";
import executeQuery from "@salesforce/apex/JT_QueryViewerController.executeQuery";

jest.mock(
  "@salesforce/apex/JT_QueryViewerController.assessQueryRisk",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/JT_QueryViewerController.executeQuery",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

function selectConfig(element) {
  const combobox = element.shadowRoot.querySelector(
    "c-jt-searchable-combobox"
  );
  combobox.dispatchEvent(
    new CustomEvent("select", {
      detail: {
        value: "Test_Record",
        data: {
          baseQuery: "SELECT Id, Name FROM Account WHERE Name =: name",
          bindings: JSON.stringify({ name: "Test Account" }),
          objectName: "Account"
        }
      }
    })
  );
}

function clickExecute(element) {
  const executeButton = element.shadowRoot.querySelector(
    "c-jt-execute-button"
  );
  executeButton.dispatchEvent(new CustomEvent("execute"));
}

describe("c-jt-query-viewer: query risk assessment flow", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("shows a blocking error toast instead of executing the query unbounded when assessQueryRisk rejects", async () => {
    assessQueryRisk.mockRejectedValue({
      body: { message: "Simulated risk assessment failure" }
    });

    const element = createElement("c-jt-query-viewer", {
      is: JtQueryViewer
    });
    document.body.appendChild(element);

    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);

    selectConfig(element);
    await Promise.resolve();

    clickExecute(element);

    // Flush the assessQueryRisk() rejection through .catch()/.finally()
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(assessQueryRisk).toHaveBeenCalled();
    expect(toastHandler).toHaveBeenCalled();
    const toastEvent = toastHandler.mock.calls[0][0];
    expect(toastEvent.detail.variant).toBe("error");
  });

  it("executes normally without a modal when the risk assessment reports low risk", async () => {
    assessQueryRisk.mockResolvedValue({
      isCriticalRisk: false,
      isHighRisk: false,
      recommendBatchProcessing: false
    });
    executeQuery.mockResolvedValue({
      success: true,
      recordCount: 1,
      records: [{ Id: "001000000000001", Name: "Test Account" }],
      fields: ["Id", "Name"]
    });

    const element = createElement("c-jt-query-viewer", {
      is: JtQueryViewer
    });
    document.body.appendChild(element);

    selectConfig(element);
    await Promise.resolve();

    clickExecute(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(executeQuery).toHaveBeenCalled();
    expect(element.shadowRoot.querySelector('[role="dialog"]')).toBeNull();
  });

  it("shows the risk warning modal instead of executing when risk is critical", async () => {
    assessQueryRisk.mockResolvedValue({
      isCriticalRisk: true,
      isHighRisk: false,
      recommendBatchProcessing: false
    });

    const element = createElement("c-jt-query-viewer", {
      is: JtQueryViewer
    });
    document.body.appendChild(element);

    selectConfig(element);
    await Promise.resolve();

    clickExecute(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(executeQuery).not.toHaveBeenCalled();
    expect(
      element.shadowRoot.querySelector('[role="dialog"]')
    ).not.toBeNull();
  });
});
