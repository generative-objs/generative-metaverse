// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.12;

library SharedStruct {
    struct ZoneInfo {
        uint256 zoneIndex; // required
        address coreTeamAddr; // required for type=1
        address collAddr; // required for type=2 
        uint256 typeZone; //1: team ,2: nft hodler, 3: public
    }

    struct SpaceInfo {
        bytes1 _x;
        bytes1 _y;
        bytes1 _z;
        bytes1 _padding;
    }
}