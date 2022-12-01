pragma solidity ^0.8.0;

library Metaverse {
    uint256 constant PERCENT_MIN = 10000;

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
        address _collAddr;
        uint256 _size;
    }

}
