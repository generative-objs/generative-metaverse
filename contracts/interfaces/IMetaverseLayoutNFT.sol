// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "../lib/helpers/BoilerplateParam.sol";

interface IMetaverseLayoutNFT {
    event MintSpace(address sender, MintRequest request);

    struct MintRequest {
        uint256 _metaverseId;
        uint256 _zoneIndex;
        address _mintTo;
        uint256[] _spaceIdBatch;
        uint256[] _erc721TokenId;
        string[] _uriBatch;
        BoilerplateParam.ParamsOfProject[] _paramsBatch;
    }

}