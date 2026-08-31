/**
 * @description Thrown when record-count or selectivity risk assessment cannot be completed
 * for an LDV-guarded query. Callers must handle this explicitly - no code path may catch it
 * and fall through to an unbounded query, since a failed risk assessment is itself evidence
 * the query may be expensive or unselective.
 * @author Jaime Terrats
 * @group LDV
 */
public class JT_LdvRiskAssessmentException extends Exception {
}
