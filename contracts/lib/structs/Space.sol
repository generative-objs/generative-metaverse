pragma solidity ^0.8.0;

library Space {
    struct MetaverseInfo {
        uint256 _fee;
        address _feeTokenAddr;
        address _creator;
        address _nftGated;
    }

    struct SpaceInfo {
        string _customUri;
        uint256 _metaverseId;
        SpaceData _spaceData;
    }

    struct SpaceData {
        SpacePosition _position;
        SpaceScale _scale;
        SpaceVelocity _velocity;
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

    struct SpaceVelocity {
        bytes _x;
        bytes _y;
        bytes _z;
    }
}
