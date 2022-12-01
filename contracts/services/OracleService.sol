pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';

import "../interfaces/IOracleService.sol";
import "../interfaces/ICallback.sol";

import "../lib/helpers/Errors.sol";
import "../lib/helpers/StringUtils.sol";


contract OracleService is ReentrancyGuard, Ownable, IOracleService, ChainlinkClient {
    using Chainlink for Chainlink.Request;
    using CBORChainlink for BufferChainlink.buffer;

    // admin variable
    address public _admin;
    address public _operator;

    // oracle variable
    mapping(bytes32 => address) _callbackAddrs;

    constructor (address admin, address LINK_TOKEN, address ORACLE) {
        _admin = admin;

        // init for oracle
        setChainlinkToken(LINK_TOKEN);
        setChainlinkOracle(ORACLE);
    }

    function changeAdmin(address newAdm) external {
        require(msg.sender == _admin && newAdm != address(0) && _admin != newAdm, Errors.ONLY_ADMIN_ALLOWED);
        _admin = newAdm;
    }

    function changeOperator(address be) external {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        _operator = _operator;
    }

    function changeOracle(address oracle) external {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        setChainlinkOracle(oracle);
    }

    function changeLINKToken(address LINK_TOKEN) external {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        setChainlinkToken(LINK_TOKEN);
    }

    function withdrawLink() external nonReentrant {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), 'Unable to transfer');
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        (bool success,) = msg.sender.call{value : address(this).balance}("");
        require(success);
    }

    /* @Oracle feature
    */

    function requestData(string memory jobId, uint256 fee, string memory url, string memory path, address callback) external override returns (bytes32 requestId) {
        require(msg.sender == _admin || msg.sender == _operator, Errors.ONLY_ADMIN_ALLOWED);
        require(callback != address(0x0), Errors.INV_ADD);
        require(callback.code.length > 0, Errors.INV_ADD);

        Chainlink.Request memory req = buildChainlinkRequest(StringUtils.stringToBytes32(jobId), address(this), this.fulfill.selector);
        req.add('get', url);
        req.add('path', path);

        // create and send request
        requestId = sendChainlinkRequest(req, fee);

        // store collback address        
        _callbackAddrs[requestId] = callback;
        return requestId;
    }

    function fulfill(bytes32 requestId, bytes memory gameData) external override recordChainlinkFulfillment(requestId) {
        emit IOracleService.RequestFulfilledData(requestId, gameData);
        require(_callbackAddrs[requestId] != address(0));
        ICallback callBack = ICallback(_callbackAddrs[requestId]);
        callBack.fulfill(requestId, gameData);
    }

}
