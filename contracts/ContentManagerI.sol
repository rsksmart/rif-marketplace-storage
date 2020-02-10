pragma solidity 0.6.2;

interface ContentManagerI {
    function setFileReference(bytes32 requestReference, bytes32[] calldata fileReference) external;
    function AcknoledgeUpdatedContentIdentifier() external;
    function callNewRequest(bytes32[] calldata fileReference, address provider, uint120 size, uint64 period, uint256 payment) external;
    function callStopRequestBefore(bytes32[] calldata fileReference, address provider) external;
    function callStopRequestDuring(bytes32[] calldata fileReference, address provider) external;
    function callTopUpRequest(bytes32[] calldata fileReference, address provider, uint256 payment) external;
}