pragma solidity ^0.8.0;

interface IOracleService {
    event RequestFulfilledData(bytes32 indexed requestId, bytes indexed data);

    function requestData(string memory jobId, uint256 fee, string memory url, string memory path, address callback) external returns (bytes32 requestId);

    function fulfill(bytes32 requestId, bytes memory gameData) external;
}
