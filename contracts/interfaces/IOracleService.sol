pragma solidity ^0.8.0;

interface IOracleService {
    event RequestFulfilledData(bytes32 indexed requestId, bytes indexed data);
}
