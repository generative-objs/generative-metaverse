// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.12;

library SharedStruct {
    struct MetaverseInfo {
        uint256 _fee; // fee for mint space from layout default frees
        address _feeTokenAddr;// fee currency for mint space from layout default is native token
        address _creator; // creator list for project, using for royalties
        string _algo; // script render: 1/ simplescript 2/ ipfs:// protocol
        uint256 _size;
        address _spaceAddress;
        mapping(uint256 => ZoneInfo) _metaverseZones;
    }

    struct ZoneInfo {
        uint256 zoneIndex; // required
        address coreTeamAddr; // required for type=1
        address collAddr; // required for type=2 
        uint256 typeZone; //1: team ,2: nft hodler, 3: public
    }

    struct SpaceToken {
        string _customUri;
        address _creator;
        bool _init;
        SpaceData _spaceData;
    }

    struct SpaceData {
        bytes1 _x;
        bytes1 _y;
        bytes1 _z;
        bytes1 _padding;
    }
}