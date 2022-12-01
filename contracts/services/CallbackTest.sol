pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../lib/helpers/Errors.sol";
import "../interfaces/ICallback.sol";

contract CallbackTest is Initializable, ICallback {

    address public _oracleServiceAddr;
    constructor(address oracleServiceAddr) {
        _oracleServiceAddr = oracleServiceAddr;
        // TODO: do something
    }

    function fulfill(bytes32 requestId, bytes memory data) external {
        require(msg.sender == _oracleServiceAddr, Errors.INV_ADD);
        emit FulfillEvent(requestId, data);
        // TODO dosomething
    }
}
