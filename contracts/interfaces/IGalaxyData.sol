pragma solidity ^0.8.0;

interface IGalaxyData {
    function getTraitsName() external view returns (bytes[] memory);

    function getAvailableTraits() external view returns (bytes[][] memory);
}
