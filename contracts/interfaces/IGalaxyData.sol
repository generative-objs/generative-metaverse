pragma solidity ^0.8.0;

interface IGalaxyData {
    function getTraits() external view returns (bytes[] memory);

    function getTraitsAvailableValues() external view returns (bytes[][] memory);

    function tokenURI(uint256 seed) external view returns (string memory result);

    function tokenHTML(uint256 seed) external view returns (string memory result);
}
