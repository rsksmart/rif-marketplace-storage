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
      - *Billing Periods* - Specifies periods that are available to used for billing   
      - *Billing Prices* - Specifies prices for each Billing Period, resulting in period-price tuple.
      - *Maximum Duration* - Duration which Consumer can maximally rent the storage space for 
      - *Total Capacity* - Total capacity that Provider is offering
      - *Free Capacity* - Capacity in given time that is left free for Consumers to use  
      - *Location* - Approximate location of the provider
      - *Storage System* - Offer is always connected to one Storage System like IPFS or Swarm
      - *Offer Termination* - Provider can choose to discontinue his Offer. No new Agreements will be accepted, but current Agreements will be finished based on their current Billing Period.
    - **Data Source** - Data Source is an abstract entity that defines the data that should be stored under an Agreement. There might be different mechanisms on how files should be retrieved, updated and removed.
      - *IPFS Source* - Hash pointer to immutable data source.
      - *Contract Source* - Pointer to different smart-contract that handles the mutability (eq. adding/removing files) 
      - *IPNS Source* - [That is the future babe.](https://gph.is/1FD4aQ0)
      - *RNS Source* - [That is also the future babe.](https://gph.is/1FD4aQ0)
    - **Agreement** - Consumer creates Agreement for a specific Provider's Offer, specifying and the corresponding Data Source
      - *Data Reference* - Pointer to Data Source
      - *Agreement Termination* - Consumer can decide to terminate the agreement, which will take effect after finishing of current billing period.
      - *Deposit Funds* - In order for an Agreement to be active, it needs to have available funds for each Billing Period renewal. Consumer can therefore deposit funds.
      - *Payout Funds* - Upon finishing of a Billing Period, the Provider can request the funds for the finished periods to be transferred to him. 
      - *Active Agreement* - Active Agreement is that one that had sufficient funds to pay for the current Billing Period. Provider stores and provide the files specified by Data Reference. When it runs out of funds it will become "Inactive Agreement"
      - *Inactive Agreement* - Inactive Agreement is that one that ran out of funds and therefore the Provider is not required to store and provide the files defined in Data Reference.
