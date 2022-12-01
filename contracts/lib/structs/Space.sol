pragma solidity ^0.8.0;

library Space {
    struct SpaceToken {
        string _customUri;
        uint256 _fee;
        address _feeTokenAddr;
        address _creator;
        bool _init;
        address _metaverseAddr;
        address _metaverseId;
        SpaceData _spaceData;
    }

    struct SpaceData {
        SpacePosition _position;
        SpaceScale _scale;
        bytes _padding;
    }

    struct SpacePosition {
        bytes _x;
        bytes _y;
        bytes _z;
    }

    struct SpaceScale {
        bytes _x;
        bytes _y;
        bytes _z;
    }
}
