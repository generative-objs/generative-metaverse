pragma solidity ^0.8.0;

library Galaxy {
    uint256 constant PERCENT_MIN = 10000;

    struct GalaxyTokenInfo {
        uint256 _fee;
        address _feeTokenAddr;
        address _creator;
        address _spaceAddr;
        string _algo; // metaverse algo for generative space
        string _customUri;
        ZoneInfo[] _zones;
    }

    struct ZoneInfo {
        address _collAddr;
        uint256 _size;
    }

    struct GalaxyURIContext {
        string script;
        string imageURI;
        string animationURI;
        string name;
    }
}

library GalaxyTraits {
    uint256 constant traitsSize = 3;
    uint256 constant traits_0_Size = 4;
}
