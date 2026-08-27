/**
 * @description Minimal JT_DataSelector.CursorProcessor implementation for chained LDV
 * operations that have no side-effecting work of their own yet - it proves the chunk
 * fetch/re-instantiation pipeline without holding any cross-transaction state. Real
 * export/integration processors implement the same interface and are supplied by the caller
 * via JT_LDV_Checkpoint__c.JT_ProcessorClass__c.
 * Requires a public no-arg constructor - re-instantiated once per chunk, per Queueable
 * transaction, since instances cannot be serialized across transactions.
 * @author Jaime Terrats
 * @group LDV
 */
public class JT_LdvCountingProcessor implements JT_DataSelector.CursorProcessor {
  public void processBatch(List<SObject> batch) {
  }
}
