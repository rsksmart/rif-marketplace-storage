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
    - **Consumer** - actor that wants his files to be persisted in the network.
    - **Provider** - actor that offers his storage for Consumers to be used in monetary exchange.
 - Entities
    - **Offer** - Offer created by Provider that announces availability of his storage space.
      - *Billing Periods* - Specifies periods how often is payment required (e.g. every month, every 2 months...).
      - *Billing Prices* - Specifies prices per byte for each Billing Period, resulting in period-price tuple.
      - *Maximum Duration* - Duration which Consumer can maximally rent the storage space for. 
      - *Total Capacity* - Total capacity in bytes that Provider is offering.
      - *Available Capacity* - Capacity in bytes in given time that is left free for Consumers to use.
      - *Utilized Capacity* - Capacity in bytes which is currently being utilized by active Agreements.
      - *Location* - Optional, self proclaimed location (country) from which the service is provided (where the data will be stored).
      - *Storage Network* - Offer is always connected to one Storage System like IPFS or Swarm.
      - *Offer Termination* - Provider can choose to discontinue his Offer. No new Agreements will be accepted, but current Agreements will be finished based on the number of Billing Periods already purchased.
    - **Data Source** - Data Source is an abstract entity that defines the data that should be stored under an Agreement. There might be different mechanisms on how files should be retrieved, updated and removed.
      - *IPFS Source* - Hash pointer to immutable data source.
      - *Contract Source* - Pointer to different smart-contract that handles the mutability (eq. adding/removing files) 
      - *IPNS Source* - [That is the future babe.](https://gph.is/1FD4aQ0)
      - *RNS Source* - [That is also the future babe.](https://gph.is/1FD4aQ0)
      - *Swarm Feeds Source* - [That is also the future babe.](https://gph.is/1FD4aQ0)
    - **Agreement** - Consumer creates Agreement for a specific Provider's Offer, specifying and the corresponding Data Source
      - *Data Reference* - Pointer to Data Source
      - *Agreement Termination* - Consumer can decide to terminate the agreement, which will take effect after finishing of current billing period.
      - *Deposit Funds* - In order for an Agreement to be active, it needs to have available funds for each Billing Period renewal. Consumer can therefore deposit funds.
      - *Withdraw Funds* - Customer can withdraw deposited funds, which have not be used for Billing Period renewal.
      - *Payout Funds* - Upon finishing of a Billing Period, the Provider can request the funds for the finished periods to be transferred to him. 
      - *Active Agreement* - Active Agreement is that one that had sufficient funds to pay for the current Billing Period. Provider stores and provide the files specified by Data Reference. When it runs out of funds it will become "Inactive Agreement".
      - *Inactive Agreement* - Inactive Agreement is that one that ran out of funds and therefore the Provider is not required to store and provide the files defined in Data Reference.
