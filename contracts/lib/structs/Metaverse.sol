pragma solidity ^0.8.0;

library Metaverse {
    uint256 constant NFTGATED = 1;
    uint256 constant NONFTGATED = 2;

    struct MetaverseInfo {
        uint256 _fee;
        address _feeTokenAddr;
        address _creator;
        address _spaceAddr;
        string _algo;
        string _customUri;
        ZoneInfo[] _zones;
    }

    struct ZoneInfo {
        address collAddr; // required for type=1
        uint256 typeZone; //1: nft hodler, 2: public
    }

}
