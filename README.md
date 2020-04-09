# RIF Marketplace Storage Pinning

```
npm i @rsksmart/rif-marketplace-storage-pinning
```

## PinningManager contract

### Message
The `StorageProvider` can emit an arbitrary message in the function calls `setStorageOffer` and `emitMessage`. 
The message is is initially intended to allow the `StorageProvider` to communicate his `nodeID`, but may be used for other purposes later.

The client should be instructed to enforce the following semantics:
- If `message` starts with `0x01`, then the following bits contain an arbitrary length `nodeID`.

## Glossary

 - Actors
    - **Consumer** - actor that wants his files to be persisted in the network
    - **Provider** - actor that offers his storage for Consumers to be used in monetary exchange
 - Entities
    - **Offer** - Offer created by Provider that announces availability of his storage space
      - *Billing Period* - Specifies price for recurring period of time (e.g. 10 wei per day ) 
      - *Maximum Duration* - Duration which Consumer can maximally rent the storage space for 
      - *Total Capacity* - Total capacity that Provider is offering
      - *Free Capacity* - Capacity in given time that is left free for Consumers to use  
      - *Location* - Approximate location of the provider
      - *Offer Termination* - Provider can choose to discontinue his Offer. No new Agreements will be accepted, but current Agreements will be finished based on their current Billing Period.
    - **Data Source** - Data Source is an abstract entity that defines the data that should be stored under an Agreement. There might be different mechanisms on how files should be retrieved, updated and removed.
      - *IPFS Source* - Hash pointer to immutable data source.
      - *Contract Source* - Pointer to different smart-contract that handles the mutability (eq. adding/removing files) 
      - *IPNS Source* - [That is the future babe.](https://gph.is/1FD4aQ0)
    - **Agreement** - Consumer creates Agreement for a specific Provider's Offer, specifying and the corresponding Data Source
      - **Data Reference** - Pointer to Data Source
      - **Agreement Termination** - Consumer can decide to terminate the agreement, which will take effect after finishing of current billing period.
      - **Deposit Funds** - In order for Agreement to be active, it has to have available funds for each Billing Period renewal. Consumer can therefore deposit funds.
      - **Payout Funds** - Upon finishing of a Billing Period, the Provider can request the funds for finished period to be transferred to him. 
