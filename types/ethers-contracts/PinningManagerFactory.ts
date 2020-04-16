/* Generated by ts-generator ver. 0.0.8 */
/* tslint:disable */

import { Contract, ContractFactory, Signer } from "ethers";
import { Provider } from "ethers/providers";
import { UnsignedTransaction } from "ethers/utils/transaction";

import { TransactionOverrides } from ".";
import { PinningManager } from "./PinningManager";

export class PinningManagerFactory extends ContractFactory {
  constructor(signer?: Signer) {
    super(_abi, _bytecode, signer);
  }

  deploy(overrides?: TransactionOverrides): Promise<PinningManager> {
    return super.deploy(overrides) as Promise<PinningManager>;
  }
  getDeployTransaction(overrides?: TransactionOverrides): UnsignedTransaction {
    return super.getDeployTransaction(overrides);
  }
  attach(address: string): PinningManager {
    return super.attach(address) as PinningManager;
  }
  connect(signer: Signer): PinningManagerFactory {
    return super.connect(signer) as PinningManagerFactory;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): PinningManager {
    return new Contract(address, _abi, signerOrProvider) as PinningManager;
  }
}

const _abi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "storer",
        type: "address"
      },
      {
        indexed: false,
        internalType: "uint128",
        name: "capacity",
        type: "uint128"
      }
    ],
    name: "CapacitySet",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "requestReference",
        type: "bytes32"
      }
    ],
    name: "EarningsWithdrawn",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "storer",
        type: "address"
      },
      {
        indexed: false,
        internalType: "uint128",
        name: "maximumDuration",
        type: "uint128"
      }
    ],
    name: "MaximumDurationSet",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "storer",
        type: "address"
      },
      {
        indexed: false,
        internalType: "bytes32[]",
        name: "message",
        type: "bytes32[]"
      }
    ],
    name: "MessageEmitted",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "storer",
        type: "address"
      },
      {
        indexed: false,
        internalType: "uint64",
        name: "period",
        type: "uint64"
      },
      {
        indexed: false,
        internalType: "uint64",
        name: "price",
        type: "uint64"
      }
    ],
    name: "PriceSet",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "bytes32",
        name: "requestReference",
        type: "bytes32"
      },
      {
        indexed: true,
        internalType: "bytes32[]",
        name: "fileReference",
        type: "bytes32[]"
      },
      {
        indexed: true,
        internalType: "address",
        name: "requester",
        type: "address"
      },
      {
        indexed: true,
        internalType: "address",
        name: "provider",
        type: "address"
      },
      {
        indexed: false,
        internalType: "uint128",
        name: "size",
        type: "uint128"
      },
      {
        indexed: false,
        internalType: "uint64",
        name: "period",
        type: "uint64"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "deposited",
        type: "uint256"
      }
    ],
    name: "RequestMade",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "requestReference",
        type: "bytes32"
      }
    ],
    name: "RequestStopped",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "requestReference",
        type: "bytes32"
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "deposited",
        type: "uint256"
      }
    ],
    name: "RequestTopUp",
    type: "event"
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address"
      }
    ],
    name: "offerRegistry",
    outputs: [
      {
        internalType: "uint128",
        name: "capacity",
        type: "uint128"
      },
      {
        internalType: "uint128",
        name: "maximumDuration",
        type: "uint128"
      }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "uint128",
        name: "capacity",
        type: "uint128"
      },
      {
        internalType: "uint128",
        name: "maximumDuration",
        type: "uint128"
      },
      {
        internalType: "uint64[]",
        name: "periods",
        type: "uint64[]"
      },
      {
        internalType: "uint64[]",
        name: "pricesForPeriods",
        type: "uint64[]"
      },
      {
        internalType: "bytes32[]",
        name: "message",
        type: "bytes32[]"
      }
    ],
    name: "setStorageOffer",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "uint128",
        name: "increase",
        type: "uint128"
      }
    ],
    name: "increaseStorageCapacity",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "uint128",
        name: "decrease",
        type: "uint128"
      }
    ],
    name: "decreaseStorageCapacity",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [],
    name: "stopStorage",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "uint64[]",
        name: "periods",
        type: "uint64[]"
      },
      {
        internalType: "uint64[]",
        name: "pricesForPeriods",
        type: "uint64[]"
      }
    ],
    name: "setStoragePrice",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "uint128",
        name: "maximumDuration",
        type: "uint128"
      }
    ],
    name: "setMaximumDuration",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "bytes32[]",
        name: "message",
        type: "bytes32[]"
      }
    ],
    name: "emitMessage",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "bytes32[]",
        name: "fileReference",
        type: "bytes32[]"
      },
      {
        internalType: "address payable",
        name: "provider",
        type: "address"
      },
      {
        internalType: "uint128",
        name: "size",
        type: "uint128"
      },
      {
        internalType: "uint64",
        name: "period",
        type: "uint64"
      }
    ],
    name: "newRequest",
    outputs: [],
    stateMutability: "payable",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "bytes32[]",
        name: "fileReference",
        type: "bytes32[]"
      },
      {
        internalType: "address",
        name: "provider",
        type: "address"
      }
    ],
    name: "topUpRequest",
    outputs: [],
    stateMutability: "payable",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "bytes32[]",
        name: "fileReference",
        type: "bytes32[]"
      },
      {
        internalType: "address",
        name: "provider",
        type: "address"
      }
    ],
    name: "stopRequestDuring",
    outputs: [],
    stateMutability: "payable",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "bytes32[]",
        name: "requestReferences",
        type: "bytes32[]"
      }
    ],
    name: "withdrawEarnings",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "bytes32[]",
        name: "fileReference",
        type: "bytes32[]"
      }
    ],
    name: "getRequestReference",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32"
      }
    ],
    stateMutability: "view",
    type: "function"
  }
];

const _bytecode =
  "0x608060405234801561001057600080fd5b50612f1f806100206000396000f3fe6080604052600436106100c25760003560e01c8063915fe5941161007f578063c2e62ade11610059578063c2e62ade146106ef578063cb6577c014610914578063f2e98fd5146109ed578063f72f1aa714610ac5576100c2565b8063915fe5941461044157806399f29a6214610549578063a33849da146106a2576100c2565b80632fd09ef9146100c7578063511e22841461018c5780635f52618c1461026457806374147b2a1461027b5780637f04cc92146102c85780638f5c5fc81461038d575b600080fd5b3480156100d357600080fd5b5061018a600480360360208110156100ea57600080fd5b810190808035906020019064010000000081111561010757600080fd5b82018360208201111561011957600080fd5b8035906020019184602083028401116401000000008311171561013b57600080fd5b919080806020026020016040519081016040528093929190818152602001838360200280828437600081840152601f19601f820116905080830192505050505050509192919290505050610b12565b005b610262600480360360408110156101a257600080fd5b81019080803590602001906401000000008111156101bf57600080fd5b8201836020820111156101d157600080fd5b803590602001918460208302840111640100000000831117156101f357600080fd5b919080806020026020016040519081016040528093929190818152602001838360200280828437600081840152601f19601f820116905080830192505050505050509192919290803573ffffffffffffffffffffffffffffffffffffffff169060200190929190505050610b1e565b005b34801561027057600080fd5b506102796111ff565b005b34801561028757600080fd5b506102c66004803603602081101561029e57600080fd5b8101908080356fffffffffffffffffffffffffffffffff16906020019092919050505061124f565b005b3480156102d457600080fd5b5061038b600480360360208110156102eb57600080fd5b810190808035906020019064010000000081111561030857600080fd5b82018360208201111561031a57600080fd5b8035906020019184602083028401116401000000008311171561033c57600080fd5b919080806020026020016040519081016040528093929190818152602001838360200280828437600081840152601f19601f8201169050808301925050505050505091929192905050506112f5565b005b34801561039957600080fd5b506103dc600480360360208110156103b057600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff16906020019092919050505061189a565b60405180836fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff168152602001826fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff1681526020019250505060405180910390f35b6105476004803603608081101561045757600080fd5b810190808035906020019064010000000081111561047457600080fd5b82018360208201111561048657600080fd5b803590602001918460208302840111640100000000831117156104a857600080fd5b919080806020026020016040519081016040528093929190818152602001838360200280828437600081840152601f19601f820116905080830192505050505050509192919290803573ffffffffffffffffffffffffffffffffffffffff16906020019092919080356fffffffffffffffffffffffffffffffff169060200190929190803567ffffffffffffffff1690602001909291905050506118f6565b005b34801561055557600080fd5b506106a06004803603604081101561056c57600080fd5b810190808035906020019064010000000081111561058957600080fd5b82018360208201111561059b57600080fd5b803590602001918460208302840111640100000000831117156105bd57600080fd5b919080806020026020016040519081016040528093929190818152602001838360200280828437600081840152601f19601f8201169050808301925050505050505091929192908035906020019064010000000081111561061d57600080fd5b82018360208201111561062f57600080fd5b8035906020019184602083028401116401000000008311171561065157600080fd5b919080806020026020016040519081016040528093929190818152602001838360200280828437600081840152601f19601f8201169050808301925050505050505091929192905050506121b1565b005b3480156106ae57600080fd5b506106ed600480360360208110156106c557600080fd5b8101908080356fffffffffffffffffffffffffffffffff16906020019092919050505061224f565b005b3480156106fb57600080fd5b50610912600480360360a081101561071257600080fd5b8101908080356fffffffffffffffffffffffffffffffff16906020019092919080356fffffffffffffffffffffffffffffffff1690602001909291908035906020019064010000000081111561076757600080fd5b82018360208201111561077957600080fd5b8035906020019184602083028401116401000000008311171561079b57600080fd5b919080806020026020016040519081016040528093929190818152602001838360200280828437600081840152601f19601f820116905080830192505050505050509192919290803590602001906401000000008111156107fb57600080fd5b82018360208201111561080d57600080fd5b8035906020019184602083028401116401000000008311171561082f57600080fd5b919080806020026020016040519081016040528093929190818152602001838360200280828437600081840152601f19601f8201169050808301925050505050505091929192908035906020019064010000000081111561088f57600080fd5b8201836020820111156108a157600080fd5b803590602001918460208302840111640100000000831117156108c357600080fd5b919080806020026020016040519081016040528093929190818152602001838360200280828437600081840152601f19601f82011690508083019250505050505050919291929050505061229f565b005b34801561092057600080fd5b506109d76004803603602081101561093757600080fd5b810190808035906020019064010000000081111561095457600080fd5b82018360208201111561096657600080fd5b8035906020019184602083028401116401000000008311171561098857600080fd5b919080806020026020016040519081016040528093929190818152602001838360200280828437600081840152601f19601f820116905080830192505050505050509192919290505050612368565b6040518082815260200191505060405180910390f35b610ac360048036036040811015610a0357600080fd5b8101908080359060200190640100000000811115610a2057600080fd5b820183602082011115610a3257600080fd5b80359060200191846020830284011164010000000083111715610a5457600080fd5b919080806020026020016040519081016040528093929190818152602001838360200280828437600081840152601f19601f820116905080830192505050505050509192919290803573ffffffffffffffffffffffffffffffffffffffff1690602001909291905050506123fc565b005b348015610ad157600080fd5b50610b1060048036036020811015610ae857600080fd5b8101908080356fffffffffffffffffffffffffffffffff1690602001909291905050506127b2565b005b610b1b81612858565b50565b6000610b2983612368565b905060008060008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002090506000816002016000848152602001908152602001600020905060008260000160009054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff161415610c12576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252602d815260200180612e92602d913960400191505060405180910390fd5b60008160010160109054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff161415610c9e576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526022815260200180612dc36022913960400191505060405180910390fd5b60008260010160008360000160089054906101000a900467ffffffffffffffff1667ffffffffffffffff1667ffffffffffffffff16815260200190815260200160002060009054906101000a900467ffffffffffffffff1667ffffffffffffffff161415610d57576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252602b815260200180612ebf602b913960400191505060405180910390fd5b60003414158015610d93575060008160000160009054906101000a900467ffffffffffffffff1667ffffffffffffffff163481610d9057fe5b06145b610de8576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526035815260200180612e366035913960400191505060405180910390fd5b428160000160089054906101000a900467ffffffffffffffff1667ffffffffffffffff168260000160109054906101000a900467ffffffffffffffff1667ffffffffffffffff168360010160109054906101000a90046fffffffffffffffffffffffffffffffff1601026fffffffffffffffffffffffffffffffff161115610ed8576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601f8152602001807f50696e6e696e674d616e616765723a205265717565737420657870697265640081525060200191505060405180910390fd5b60008160000160009054906101000a900467ffffffffffffffff1667ffffffffffffffff163481610f0557fe5b0490508260000160109054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff166110058360000160089054906101000a900467ffffffffffffffff1667ffffffffffffffff16610f96848660000160089054906101000a900467ffffffffffffffff1667ffffffffffffffff166128ea90919063ffffffff16565b8560010160109054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff16420381610fd257fe5b048560000160109054906101000a900467ffffffffffffffff1667ffffffffffffffff160361297290919063ffffffff16565b11158015611051575067ffffffffffffffff801661104e8360000160109054906101000a900467ffffffffffffffff1667ffffffffffffffff16836128ea90919063ffffffff16565b11155b6110c3576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601f8152602001807f50696e6e696e674d616e616765723a20706572696f6420746f6f206c6f6e670081525060200191505060405180910390fd5b6110f88260000160009054906101000a900467ffffffffffffffff1667ffffffffffffffff168261297290919063ffffffff16565b50808260000160108282829054906101000a900467ffffffffffffffff160192506101000a81548167ffffffffffffffff021916908367ffffffffffffffff1602179055506111be8260000160089054906101000a900467ffffffffffffffff168360000160109054906101000a900467ffffffffffffffff160267ffffffffffffffff168360010160109054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff166128ea90919063ffffffff16565b50837fc0161a1b9ca96ed7eebb63025f4fa75d13deca2932c2cfb35595e474b6b18d4e346040518082815260200191505060405180910390a2505050505050565b60008060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020905061124c8160006129f8565b50565b60008060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002090506112f1816112ec846fffffffffffffffffffffffffffffffff168460000160009054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff166128ea90919063ffffffff16565b6129f8565b5050565b600080600090505b82518160ff16101561184e5760008060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000206002016000858460ff168151811061135d57fe5b60200260200101518152602001908152602001600020905060008160010160109054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff161415611401576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526022815260200180612dc36022913960400191505060405180910390fd5b428160000160089054906101000a900467ffffffffffffffff1667ffffffffffffffff168260000160109054906101000a900467ffffffffffffffff1667ffffffffffffffff168360010160109054906101000a90046fffffffffffffffffffffffffffffffff1601026fffffffffffffffffffffffffffffffff1610156116f6576114ec8160000160009054906101000a900467ffffffffffffffff168260000160189054906101000a900467ffffffffffffffff168360000160109054906101000a900467ffffffffffffffff16030267ffffffffffffffff16846128ea90919063ffffffff16565b925060008160000160186101000a81548167ffffffffffffffff021916908367ffffffffffffffff16021790555060008160000160106101000a81548167ffffffffffffffff021916908367ffffffffffffffff16021790555060008060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060000160009054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff16146116b5578060010160009054906101000a90046fffffffffffffffffffffffffffffffff166000803373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060000160009054906101000a90046fffffffffffffffffffffffffffffffff16016000803373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060000160006101000a8154816fffffffffffffffffffffffffffffffff02191690836fffffffffffffffffffffffffffffffff1602179055505b60008160010160106101000a8154816fffffffffffffffffffffffffffffffff02191690836fffffffffffffffffffffffffffffffff1602179055506117fd565b60008160000160089054906101000a900467ffffffffffffffff1667ffffffffffffffff168260010160109054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff1642038161175757fe5b0490506117b58260000160009054906101000a900467ffffffffffffffff1667ffffffffffffffff168360000160189054906101000a900467ffffffffffffffff1667ffffffffffffffff16830302856128ea90919063ffffffff16565b9350808260000160188282829054906101000a900467ffffffffffffffff160192506101000a81548167ffffffffffffffff021916908367ffffffffffffffff160217905550505b838260ff168151811061180c57fe5b60200260200101517f4ac42bf24a33f8a33951634c9cdf69b8c8263e3d16bbe8fa48e167692a36712e60405160405180910390a25080806001019150506112fd565b503373ffffffffffffffffffffffffffffffffffffffff166108fc829081150290604051600060405180830381858888f19350505050158015611895573d6000803e3d6000fd5b505050565b60006020528060005260406000206000915090508060000160009054906101000a90046fffffffffffffffffffffffffffffffff16908060000160109054906101000a90046fffffffffffffffffffffffffffffffff16905082565b60008167ffffffffffffffff16141561195a576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526027815260200180612e6b6027913960400191505060405180910390fd5b600061196585612368565b905060008060008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060010160008467ffffffffffffffff1667ffffffffffffffff16815260200190815260200160002060009054906101000a900467ffffffffffffffff16905060008167ffffffffffffffff161415611a4a576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526030815260200180612e066030913960400191505060405180910390fd5b60003414158015611a6e575060008167ffffffffffffffff163481611a6b57fe5b06145b611ac3576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526035815260200180612e366035913960400191505060405180910390fd5b60008060008773ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000209050600081600201600085815260200190815260200160002090506000428260000160089054906101000a900467ffffffffffffffff168360000160109054906101000a900467ffffffffffffffff160267ffffffffffffffff168360010160109054906101000a90046fffffffffffffffffffffffffffffffff16016fffffffffffffffffffffffffffffffff1610905060008260010160109054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff161480611bd35750805b611c28576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526026815260200180612d6c6026913960400191505060405180910390fd5b8015611e115760008360000160009054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff161415611cba576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252602d815260200180612e92602d913960400191505060405180910390fd5b6000611d2d8360000160009054906101000a900467ffffffffffffffff1667ffffffffffffffff168460000160189054906101000a900467ffffffffffffffff168560000160109054906101000a900467ffffffffffffffff160367ffffffffffffffff1661297290919063ffffffff16565b905060008360000160186101000a81548167ffffffffffffffff021916908367ffffffffffffffff16021790555060008360010160106101000a8154816fffffffffffffffffffffffffffffffff02191690836fffffffffffffffffffffffffffffffff1602179055508873ffffffffffffffffffffffffffffffffffffffff166108fc829081150290604051600060405180830381858888f19350505050158015611ddd573d6000803e3d6000fd5b50857f4ac42bf24a33f8a33951634c9cdf69b8c8263e3d16bbe8fa48e167692a36712e60405160405180910390a250611ede565b868260010160006101000a8154816fffffffffffffffffffffffffffffffff02191690836fffffffffffffffffffffffffffffffff160217905550611ea3876fffffffffffffffffffffffffffffffff168460000160009054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff16612aa990919063ffffffff16565b8360000160006101000a8154816fffffffffffffffffffffffffffffffff02191690836fffffffffffffffffffffffffffffffff1602179055505b60008467ffffffffffffffff163481611ef357fe5b0490508360000160109054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff16611f468867ffffffffffffffff168361297290919063ffffffff16565b11158015611f5e575067ffffffffffffffff80168111155b611fb3576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526034815260200180612d386034913960400191505060405180910390fd5b611fd28767ffffffffffffffff168202426128ea90919063ffffffff16565b50611ff08567ffffffffffffffff168261297290919063ffffffff16565b50848360000160006101000a81548167ffffffffffffffff021916908367ffffffffffffffff160217905550868360000160086101000a81548167ffffffffffffffff021916908367ffffffffffffffff160217905550808360000160106101000a81548167ffffffffffffffff021916908367ffffffffffffffff160217905550428360010160106101000a8154816fffffffffffffffffffffffffffffffff02191690836fffffffffffffffffffffffffffffffff1602179055508873ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff168b60405180828051906020019060200280838360005b8381101561210c5780820151818401526020810190506120f1565b5050505090500191505060405180910390207f4862ca3dd4bbc28301f2791d5ec2f9f3c4d6da04e9aee35ac6b34f0822a60b09898c8c3460405180858152602001846fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff1681526020018367ffffffffffffffff1667ffffffffffffffff16815260200182815260200194505050505060405180910390a450505050505050505050565b60008060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020905060008090505b83518160ff1610156122495761223c82858360ff168151811061221857fe5b6020026020010151858460ff168151811061222f57fe5b6020026020010151612af3565b80806001019150506121f9565b50505050565b60008060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020905061229b8183612bc6565b5050565b60008060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002090506122eb81876129f8565b6122f58186612bc6565b60008090505b84518160ff16101561234b5761233e82868360ff168151811061231a57fe5b6020026020010151868460ff168151811061233157fe5b6020026020010151612af3565b80806001019150506122fb565b506000825111156123605761235f82612858565b5b505050505050565b60003382604051602001808373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1660601b8152601401828051906020019060200280838360005b838110156123d45780820151818401526020810190506123b9565b5050505090500192505050604051602081830303815290604052805190602001209050919050565b600061240783612368565b905060008060008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060020160008381526020019081526020016000209050600060018260000160089054906101000a900467ffffffffffffffff1667ffffffffffffffff168360010160109054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff164203816124c257fe5b040190508160000160109054906101000a900467ffffffffffffffff1667ffffffffffffffff16818360000160189054906101000a900467ffffffffffffffff1667ffffffffffffffff160110612564576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526031815260200180612d926031913960400191505060405180910390fd5b60008260000160106101000a81548167ffffffffffffffff021916908367ffffffffffffffff16021790555060008260000160186101000a81548167ffffffffffffffff021916908367ffffffffffffffff1602179055508160010160009054906101000a90046fffffffffffffffffffffffffffffffff166000803373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060000160009054906101000a90046fffffffffffffffffffffffffffffffff16016000803373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060000160006101000a8154816fffffffffffffffffffffffffffffffff02191690836fffffffffffffffffffffffffffffffff16021790555060008260010160106101000a8154816fffffffffffffffffffffffffffffffff02191690836fffffffffffffffffffffffffffffffff1602179055503373ffffffffffffffffffffffffffffffffffffffff166108fc8360000160009054906101000a900467ffffffffffffffff1667ffffffffffffffff1683028460000160109054906101000a900467ffffffffffffffff1667ffffffffffffffff16039081150290604051600060405180830381858888f1935050505015801561277d573d6000803e3d6000fd5b50827f97e62d4fcb08ba0c94ea45c6647c63c29d23df27d9312702babb8483befcb75760405160405180910390a25050505050565b60008060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002090506128548161284f846fffffffffffffffffffffffffffffffff168460000160009054906101000a90046fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff16612aa990919063ffffffff16565b6129f8565b5050565b3373ffffffffffffffffffffffffffffffffffffffff167f8e9ae80d46259102dfbf4ae6121dbe6548e85c8c0494163e8e0bf0e87bcd5876826040518080602001828103825283818151815260200191508051906020019060200280838360005b838110156128d45780820151818401526020810190506128b9565b505050509050019250505060405180910390a250565b600080828401905083811015612968576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601b8152602001807f536166654d6174683a206164646974696f6e206f766572666c6f77000000000081525060200191505060405180910390fd5b8091505092915050565b60008083141561298557600090506129f2565b600082840290508284828161299657fe5b04146129ed576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526021815260200180612de56021913960400191505060405180910390fd5b809150505b92915050565b808260000160006101000a8154816fffffffffffffffffffffffffffffffff02191690836fffffffffffffffffffffffffffffffff1602179055503373ffffffffffffffffffffffffffffffffffffffff167f69d0f6173277eb697bffa596e57aa02d06e5e63fb01a500dba37a261ab77a4038260405180826fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff16815260200191505060405180910390a25050565b6000612aeb83836040518060400160405280601e81526020017f536166654d6174683a207375627472616374696f6e206f766572666c6f770000815250612c77565b905092915050565b808360010160008467ffffffffffffffff1667ffffffffffffffff16815260200190815260200160002060006101000a81548167ffffffffffffffff021916908367ffffffffffffffff1602179055503373ffffffffffffffffffffffffffffffffffffffff167f434c028bed44a6c26128b453b3343eab17a8278f8abb9b0e1e77505867eae36c8383604051808367ffffffffffffffff1667ffffffffffffffff1681526020018267ffffffffffffffff1667ffffffffffffffff1681526020019250505060405180910390a2505050565b808260000160106101000a8154816fffffffffffffffffffffffffffffffff02191690836fffffffffffffffffffffffffffffffff1602179055503373ffffffffffffffffffffffffffffffffffffffff167f1486a90930ecb3ccbbec298f0658ae6e63b7397b08b38db43a2c6c578df637488260405180826fffffffffffffffffffffffffffffffff166fffffffffffffffffffffffffffffffff16815260200191505060405180910390a25050565b6000838311158290612d24576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825283818151815260200191508051906020019080838360005b83811015612ce9578082015181840152602081019050612cce565b50505050905090810190601f168015612d165780820380516001836020036101000a031916815260200191505b509250505060405180910390fd5b506000838503905080915050939250505056fe50696e6e696e674d616e616765723a20746f74616c20706572696f642065786365656473206d6178696d756d4475726174696f6e50696e6e696e674d616e616765723a205265717565737420616c72656164792061637469766550696e6e696e674d616e616765723a20726571756573742065787069726564206f7220696e206c61737420706572696f6450696e6e696e674d616e616765723a2052657175657374206e6f7420616374697665536166654d6174683a206d756c7469706c69636174696f6e206f766572666c6f7750696e6e696e674d616e616765723a20707269636520646f65736e277420657869737420666f722070726f766964657250696e6e696e674d616e616765723a2076616c75652073656e74206e6f7420636f72726573706f6e64696e6720746f20707269636550696e6e696e674d616e616765723a20706572696f64206f662030206e6f7420616c6c6f77656450696e6e696e674d616e616765723a2070726f766964657220646973636f6e74696e756564207365727669636550696e6e696e674d616e616765723a207072696365206e6f7420617661696c61626c6520616e796d6f7265a2646970667358221220b4e6694a19985f178e8f6f4c9b03f286100b1b4abb64d1e3fc35574a1baf920764736f6c63430006020033";
