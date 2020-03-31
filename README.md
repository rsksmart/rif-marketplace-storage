# rds-contracts

## message
The `StorageProvider` can emit an arbitrary message in the function calls `setStorageOffer` and `emitMessage`. The message is is initially intended to allow the `StorageProvider` to communicate his `nodeID`, but may be used for other purposes later.

The client should be instructed to enforce the following semantics:
- If `message` starts with `0x01`, then the following bits contain an arbitrary length `nodeID`.