pragma solidity ^0.8.0;

interface ICallback {
    event FulfillEvent(bytes32 requestId, bytes data);

    function fulfill(bytes32 requestId, bytes memory data) external;
}
