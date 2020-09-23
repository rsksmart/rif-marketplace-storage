<a name="0.1.0-dev.2"></a>
# 0.1.0-dev.2 (2020-09-22)


### Bug Fixes

* commented that a price change to 0 removes the period ([#33](https://github.com/rsksmart/rif-marketplace-storage/issues/33)) ([a072530](https://github.com/rsksmart/rif-marketplace-storage/commit/a072530))
* correct tracking of utilized capacity and termination of offer ([#50](https://github.com/rsksmart/rif-marketplace-storage/issues/50)) ([7e7e6ae](https://github.com/rsksmart/rif-marketplace-storage/commit/7e7e6ae))
* depositFunds strict check for billing plans ([94184e1](https://github.com/rsksmart/rif-marketplace-storage/commit/94184e1))
* disallow deposit funds to expired agreement ([1f0dd1c](https://github.com/rsksmart/rif-marketplace-storage/commit/1f0dd1c))
* error in if clause ([#35](https://github.com/rsksmart/rif-marketplace-storage/issues/35)) ([83b0f7a](https://github.com/rsksmart/rif-marketplace-storage/commit/83b0f7a))
* fix off by one error ([#21](https://github.com/rsksmart/rif-marketplace-storage/issues/21)) ([cc5c812](https://github.com/rsksmart/rif-marketplace-storage/commit/cc5c812))
* make numberOfPeriodsDeposit dependent on size ([0ccaeb1](https://github.com/rsksmart/rif-marketplace-storage/commit/0ccaeb1))
* not indexed filereference ([a7f7e37](https://github.com/rsksmart/rif-marketplace-storage/commit/a7f7e37))
* payout newAgreement for existing agreements ([23380ad](https://github.com/rsksmart/rif-marketplace-storage/commit/23380ad))
* payoutFunds should not do anything if nothing is to be payed ([b22a13c](https://github.com/rsksmart/rif-marketplace-storage/commit/b22a13c))
* solc version mismatch ([#4](https://github.com/rsksmart/rif-marketplace-storage/issues/4)) ([5d05e26](https://github.com/rsksmart/rif-marketplace-storage/commit/5d05e26))


### Features

* add solidity contracts to the released package ([68eaec4](https://github.com/rsksmart/rif-marketplace-storage/commit/68eaec4))
* adjust NewAgreement event ([#133](https://github.com/rsksmart/rif-marketplace-storage/issues/133)) ([41eb64f](https://github.com/rsksmart/rif-marketplace-storage/commit/41eb64f))
* agreement funds support and operations around it ([#46](https://github.com/rsksmart/rif-marketplace-storage/issues/46)) ([dde817f](https://github.com/rsksmart/rif-marketplace-storage/commit/dde817f))
* allow storageProvider to emit message ([#20](https://github.com/rsksmart/rif-marketplace-storage/issues/20)) ([301c36a](https://github.com/rsksmart/rif-marketplace-storage/commit/301c36a))
* change billinprice to uint128 ([25b780a](https://github.com/rsksmart/rif-marketplace-storage/commit/25b780a))
* change sizes variables to uint64 ([2a93a9e](https://github.com/rsksmart/rif-marketplace-storage/commit/2a93a9e))
* changing comments about storage unit to megabytes ([00a3751](https://github.com/rsksmart/rif-marketplace-storage/commit/00a3751))
* enforce max-duration of period ([#51](https://github.com/rsksmart/rif-marketplace-storage/issues/51)) ([fb9fa56](https://github.com/rsksmart/rif-marketplace-storage/commit/fb9fa56))
* multicurrency ([#113](https://github.com/rsksmart/rif-marketplace-storage/issues/113)) ([4362f13](https://github.com/rsksmart/rif-marketplace-storage/commit/4362f13))
* remove accept request flow ([#22](https://github.com/rsksmart/rif-marketplace-storage/issues/22)) ([a4e0bc2](https://github.com/rsksmart/rif-marketplace-storage/commit/a4e0bc2))
* staking support ([#132](https://github.com/rsksmart/rif-marketplace-storage/issues/132)) ([51a0734](https://github.com/rsksmart/rif-marketplace-storage/commit/51a0734))
* support for generated types ([#52](https://github.com/rsksmart/rif-marketplace-storage/issues/52)) ([81827a4](https://github.com/rsksmart/rif-marketplace-storage/commit/81827a4))
* using only safemath for calculations ([38eb7ea](https://github.com/rsksmart/rif-marketplace-storage/commit/38eb7ea))



<a name="0.1.0-dev.1"></a>
# 0.1.0-dev.1 (2020-08-13)


### Bug Fixes

* commented that a price change to 0 removes the period ([#33](https://github.com/rsksmart/rif-marketplace-storage/issues/33)) ([a072530](https://github.com/rsksmart/rif-marketplace-storage/commit/a072530))
* correct tracking of utilized capacity and termination of offer ([#50](https://github.com/rsksmart/rif-marketplace-storage/issues/50)) ([7e7e6ae](https://github.com/rsksmart/rif-marketplace-storage/commit/7e7e6ae))
* depositFunds strict check for billing plans ([94184e1](https://github.com/rsksmart/rif-marketplace-storage/commit/94184e1))
* disallow deposit funds to expired agreement ([1f0dd1c](https://github.com/rsksmart/rif-marketplace-storage/commit/1f0dd1c))
* error in if clause ([#35](https://github.com/rsksmart/rif-marketplace-storage/issues/35)) ([83b0f7a](https://github.com/rsksmart/rif-marketplace-storage/commit/83b0f7a))
* fix off by one error ([#21](https://github.com/rsksmart/rif-marketplace-storage/issues/21)) ([cc5c812](https://github.com/rsksmart/rif-marketplace-storage/commit/cc5c812))
* make numberOfPeriodsDeposit dependent on size ([0ccaeb1](https://github.com/rsksmart/rif-marketplace-storage/commit/0ccaeb1))
* not indexed filereference ([a7f7e37](https://github.com/rsksmart/rif-marketplace-storage/commit/a7f7e37))
* payout newAgreement for existing agreements ([23380ad](https://github.com/rsksmart/rif-marketplace-storage/commit/23380ad))
* payoutFunds should not do anything if nothing is to be payed ([b22a13c](https://github.com/rsksmart/rif-marketplace-storage/commit/b22a13c))
* solc version mismatch ([#4](https://github.com/rsksmart/rif-marketplace-storage/issues/4)) ([5d05e26](https://github.com/rsksmart/rif-marketplace-storage/commit/5d05e26))


### Features

* agreement funds support and operations around it ([#46](https://github.com/rsksmart/rif-marketplace-storage/issues/46)) ([dde817f](https://github.com/rsksmart/rif-marketplace-storage/commit/dde817f))
* allow storageProvider to emit message ([#20](https://github.com/rsksmart/rif-marketplace-storage/issues/20)) ([301c36a](https://github.com/rsksmart/rif-marketplace-storage/commit/301c36a))
* change billinprice to uint128 ([25b780a](https://github.com/rsksmart/rif-marketplace-storage/commit/25b780a))
* change sizes variables to uint64 ([2a93a9e](https://github.com/rsksmart/rif-marketplace-storage/commit/2a93a9e))
* changing comments about storage unit to megabytes ([00a3751](https://github.com/rsksmart/rif-marketplace-storage/commit/00a3751))
* enforce max-duration of period ([#51](https://github.com/rsksmart/rif-marketplace-storage/issues/51)) ([fb9fa56](https://github.com/rsksmart/rif-marketplace-storage/commit/fb9fa56))
* remove accept request flow ([#22](https://github.com/rsksmart/rif-marketplace-storage/issues/22)) ([a4e0bc2](https://github.com/rsksmart/rif-marketplace-storage/commit/a4e0bc2))
* support for generated types ([#52](https://github.com/rsksmart/rif-marketplace-storage/issues/52)) ([81827a4](https://github.com/rsksmart/rif-marketplace-storage/commit/81827a4))
* using only safemath for calculations ([38eb7ea](https://github.com/rsksmart/rif-marketplace-storage/commit/38eb7ea))



<a name="0.1.0-dev.0"></a>
# 0.1.0-dev.0 (2020-05-07)

First dev release. Includes basically working contract shallowly tested. 

### Bug Fixes

* commented that a price change to 0 removes the period ([#33](https://github.com/rsksmart/rif-marketplace-storage/issues/33)) ([a072530](https://github.com/rsksmart/rif-marketplace-storage/commit/a072530))
* correct tracking of utilized capacity and termination of offer ([#50](https://github.com/rsksmart/rif-marketplace-storage/issues/50)) ([7e7e6ae](https://github.com/rsksmart/rif-marketplace-storage/commit/7e7e6ae))
* error in if clause ([#35](https://github.com/rsksmart/rif-marketplace-storage/issues/35)) ([83b0f7a](https://github.com/rsksmart/rif-marketplace-storage/commit/83b0f7a))
* fix off by one error ([#21](https://github.com/rsksmart/rif-marketplace-storage/issues/21)) ([cc5c812](https://github.com/rsksmart/rif-marketplace-storage/commit/cc5c812))
* make numberOfPeriodsDeposit dependent on size ([0ccaeb1](https://github.com/rsksmart/rif-marketplace-storage/commit/0ccaeb1))
* not indexed filereference ([a7f7e37](https://github.com/rsksmart/rif-marketplace-storage/commit/a7f7e37))
* solc version mismatch ([#4](https://github.com/rsksmart/rif-marketplace-storage/issues/4)) ([5d05e26](https://github.com/rsksmart/rif-marketplace-storage/commit/5d05e26))


### Features

* agreement funds support and operations around it ([#46](https://github.com/rsksmart/rif-marketplace-storage/issues/46)) ([dde817f](https://github.com/rsksmart/rif-marketplace-storage/commit/dde817f))
* allow storageProvider to emit message ([#20](https://github.com/rsksmart/rif-marketplace-storage/issues/20)) ([301c36a](https://github.com/rsksmart/rif-marketplace-storage/commit/301c36a))
* enforce max-duration of period ([#51](https://github.com/rsksmart/rif-marketplace-storage/issues/51)) ([fb9fa56](https://github.com/rsksmart/rif-marketplace-storage/commit/fb9fa56))
* remove accept request flow ([#22](https://github.com/rsksmart/rif-marketplace-storage/issues/22)) ([a4e0bc2](https://github.com/rsksmart/rif-marketplace-storage/commit/a4e0bc2))
* support for generated types ([#52](https://github.com/rsksmart/rif-marketplace-storage/issues/52)) ([81827a4](https://github.com/rsksmart/rif-marketplace-storage/commit/81827a4))


