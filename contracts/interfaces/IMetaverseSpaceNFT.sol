// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "../lib/structs/Metaverse.sol";

interface IMetaverseSpaceNFT {

    function initMetaverse(uint256 metaverseId, Metaverse.MetaverseInfo memory metaverseInfo) external;

    function extendMetaverse(uint256 metaverseId, Metaverse.ZoneInfo memory zone) external;
}