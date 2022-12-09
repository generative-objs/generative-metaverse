// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "../lib/structs/Galaxy.sol";

interface IGalaxyMatterNFT {

    function initMetaverse(uint256 metaverseId, Galaxy.GalaxyTokenInfo memory metaverseInfo) external;

    function extendMetaverse(uint256 metaverseId, Galaxy.ZoneInfo memory zone) external;
}