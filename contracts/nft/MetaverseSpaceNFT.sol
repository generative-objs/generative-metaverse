// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../lib/helpers/Errors.sol";
import "../lib/helpers/Utils.sol";
import "../lib/helpers/SharedStruct.sol";
import "../lib/configurations/MetaverseLayoutNFTConfiguration.sol";
import "../interfaces/IMetaverseLayoutNFT.sol";
import "../interfaces/IParameterControl.sol";
import "../interfaces/IMetaverseSpaceNFT.sol";
import "../operator-filter-registry/upgradeable/DefaultOperatorFiltererUpgradeable.sol";

contract MetaverseSpaceNFT is Initializable, ERC721PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable, IERC2981Upgradeable, IMetaverseSpaceNFT, DefaultOperatorFiltererUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _nextTokenId;

    // control infor
    address public _admin;
    address public _paramsAddr;
    address public _metaverseLayoutAddr;

    mapping(uint256 => SharedStruct.TokenInfo) public _tokens;
    mapping(uint256 => SharedStruct.MetaverseInfo) public _metaverses;
    mapping(address => mapping(uint256 => bool)) _minted;// marked erc-721 id

    function initialize(
        string memory name,
        string memory symbol,
        string memory baseUri,
        address admin,
        address paramsAddress
    ) initializer public {
        require(admin != address(0), Errors.INV_ADD);
        require(paramsAddress != address(0), Errors.INV_ADD);
        __ERC721_init(name, symbol);
        _paramsAddr = paramsAddress;
        _admin = admin;

        __Ownable_init();
        //        __DefaultOperatorFilterer_init();
        __ReentrancyGuard_init();
        __ERC721Pausable_init();
    }

    function changeAdmin(address _newAdmin) public {
        require(msg.sender == _admin && _newAdmin != address(0), Errors.INV_ADD);
        address _previousAdmin = _admin;
        _admin = _newAdmin;
    }

    function getZone(uint256 metaverseId, uint256 zoneIndex) external returns (SharedStruct.ZoneInfo memory) {
        return _metaverses[metaverseId]._metaverseZones[zoneIndex];
    }

    function validateSpaceData(uint256 metaverseId, uint256 zoneIndex, uint256 spaceIndex, SharedStruct.SpaceInfo memory spaceData) internal returns (uint256) {
        uint256 _spaceId = (metaverseId * (10 ** 9) + zoneIndex) * (10 ** 9) + (spaceIndex + 1);
        if (_tokens[_spaceId]._init) {
            return 0;
        }
        // TODO:
        return _spaceId;
    }

    // initMetaverse: init metaverse and had to call from metaverse layout contract
    // this func only can be called once. To extend metaverse, need to call function extendMetaverse
    function initMetaverse(uint256 metaverseId, address creator,
        SharedStruct.ZoneInfo memory zone,
        SharedStruct.SpaceInfo[] memory spaceDatas) external {
        // require init from template layout contract
        require(msg.sender == _metaverseLayoutAddr, Errors.INV_LAYOUT);

        // validate params
        require(zone.typeZone > 0 && zone.zoneIndex > 0, Errors.INV_ZONE);
        require(_metaverses[metaverseId]._creator == address(0), Errors.EXIST_METAVERSE);
        require(zone.typeZone > 0);
        if (zone.typeZone == 2) {
            require(zone.zoneIndex == 2, Errors.INV_ZONE);
            // set owner is admin
            _metaverses[metaverseId]._creator = _admin;
        } else if (zone.typeZone == 3) {
            require(zone.zoneIndex == 3, Errors.INV_ZONE);
            // set owner is creator who is called from metaverse layout
            require(creator != address(0));
            _metaverses[metaverseId]._creator = creator;
        }
        // set zone
        _metaverses[metaverseId]._metaverseZones[zone.zoneIndex] = zone;

        // loop for setting space info
        _metaverses[metaverseId]._size = spaceDatas.length;
        for (uint256 i = 0; i < spaceDatas.length; i++) {
            uint256 spaceId = validateSpaceData(metaverseId, zone.zoneIndex, i, spaceDatas[i]);
            require(spaceId > 0);
            _tokens[spaceId]._spaceData = spaceDatas[i];
        }

        emit InitMetaverse(metaverseId, _metaverses[metaverseId]._creator, zone, spaceDatas);
    }

    function extendMetaverse(
        uint256 metaverseId,
        SharedStruct.ZoneInfo memory zone,
        SharedStruct.SpaceInfo[] memory spaceDatas)
    external {
        // require init from template layout contract. Note: metaverse layout had to check msg.sender is owner of this metaverse
        require(msg.sender == _metaverseLayoutAddr, Errors.INV_LAYOUT);

        require(zone.typeZone > 0 && zone.zoneIndex > 0, Errors.INV_ZONE);
        require(_metaverses[metaverseId]._creator != address(0), Errors.N_EXIST_METAVERSE);
        if (_metaverses[metaverseId]._metaverseZones[2].typeZone == 2) {
            require(zone.typeZone == 2 || zone.typeZone == 3, Errors.INV_ZONE);
        } else if (_metaverses[metaverseId]._metaverseZones[2].typeZone == 3) {
            require(zone.typeZone == 3, Errors.INV_ZONE);
        }

        // set zone
        _metaverses[metaverseId]._metaverseZones[zone.zoneIndex] = zone;
        // loop for setting space info
        uint256 currentSize = _metaverses[metaverseId]._size;
        for (uint256 i = currentSize; i < spaceDatas.length + currentSize; i++) {
            uint256 spaceId = validateSpaceData(metaverseId, zone.zoneIndex, i, spaceDatas[i - currentSize]);
            require(spaceId > 0);
            _tokens[spaceId]._spaceData = spaceDatas[i];
            // update size of metaverse
            _metaverses[metaverseId]._size += 1;
        }

    }

    // mint: mint a space as token
    // 
    function paymentMintNFT(address _creator, address _feeToken, uint256 _fee) internal {
        if (_creator != msg.sender) {// not owner of project -> get payment
            // default 5% getting, 95% pay for owner of project
            uint256 operationFee = 500;
            if (_paramsAddr != address(0)) {
                IParameterControl _p = IParameterControl(_paramsAddr);
                operationFee = _p.getUInt256(MetaverseLayoutNFTConfiguration.MINT_NFT_FEE);
            }
            if (_feeToken == address(0x0)) {
                require(msg.value >= _fee);

                // pay for owner project
                (bool success,) = _creator.call{value : _fee - (_fee * operationFee / 10000)}("");
                require(success);
                // pay for host _boilerplateAddr
                (success,) = _metaverseLayoutAddr.call{value : _fee * operationFee / 10000}("");
            } else {
                IERC20Upgradeable tokenERC20 = IERC20Upgradeable(_feeToken);
                // transfer all fee erc-20 token to this contract
                require(tokenERC20.transferFrom(
                        msg.sender,
                        address(this),
                        _fee
                    ));

                // pay for owner project
                require(tokenERC20.transfer(_creator, _fee - (_fee * operationFee / 10000)));
                // pay for host _boilerplateAddr
                require(tokenERC20.transfer(_creator, _fee * operationFee / 10000));
            }
        }
    }

    function mint(uint256 metaverseId, uint256 zoneIndex, uint256 spaceId, string memory uri, bytes memory data) external {
        // TODO verify spaceId
        require(!_exists(spaceId), Errors.INV_SPACE_ID);

        if (_metaverses[metaverseId]._metaverseZones[zoneIndex].collAddr != address(0)) {
            // check nft holder
            IERC721Upgradeable erc721 = IERC721Upgradeable(_metaverses[metaverseId]._metaverseZones[zoneIndex].collAddr);
            // get token erc721 id from data
            uint256 _erc721Id = Utils.sliceUint(data, 0);
            // check owner token id
            require(erc721.ownerOf(_erc721Id) == msg.sender, "N_O_721");
            // check token not minted 
            require(!_minted[_metaverses[metaverseId]._metaverseZones[zoneIndex].collAddr][_erc721Id], "M");
            // marked this erc721 token id is minted ticket
            _minted[_metaverses[metaverseId]._metaverseZones[zoneIndex].collAddr][_erc721Id] = true;
        }

        paymentMintNFT(address(0x0), address(0x0), 0);

        _tokens[spaceId]._creator = _metaverses[metaverseId]._creator;
        _safeMint(msg.sender, spaceId);

        if (bytes(uri).length > 0) {
            _tokens[spaceId]._customUri = uri;
        }

        emit Mint(metaverseId, zoneIndex, spaceId, uri, data);
    }

    function baseTokenURI() virtual public view returns (string memory) {
        return _baseURI();
    }

    function tokenURI(uint256 _tokenId) override public view returns (string memory) {
        bytes memory customUriBytes = bytes(_tokens[_tokenId]._customUri);
        if (customUriBytes.length > 0) {
            return _tokens[_tokenId]._customUri;
        } else {
            return string(abi.encodePacked(baseTokenURI(), StringsUpgradeable.toString(_tokenId)));
        }
    }

    /** @dev EIP2981 royalties implementation. */
    // EIP2981 standard royalties return.
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view override
    returns (address receiver, uint256 royaltyAmount)
    {
        receiver = _tokens[_tokenId]._creator;
        royaltyAmount = (_salePrice * 500) / 10000;
    }

    /* @notice: EIP2981 royalties implementation. 
    // EIP2981 standard royalties return.
    */
    function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
    public
    override
    onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}