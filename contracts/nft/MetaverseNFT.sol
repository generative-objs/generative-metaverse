// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "../interfaces/IMetaverseNFT.sol";
import "../lib/helpers/Errors.sol";
import "../lib/helpers/Utils.sol";
import "../lib/helpers/SharedStruct.sol";

contract MetaverseNFT is ERC721PresetMinterPauserAutoIdUpgradeable, ReentrancyGuardUpgradeable, IERC2981Upgradeable, IMetaverseNFT {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _nextTokenId;

    // control infor
    address public _admin;
    address public _paramsAddr;
    address public _metaverseLayoutAddr;

    // nft info
    struct TokenInfo {
        string _customUri;
        address _creator;
        bool _init;
        SharedStruct.SpaceInfo _spaceData;
    }

    mapping(uint256 => TokenInfo) public _tokens;


    struct MetaverseInfo {
        address _metaverseOwner;
        mapping(uint256 => SharedStruct.ZoneInfo) _metaverseZones;
        uint256 _size;
    }

    mapping(uint256 => MetaverseInfo) public _metaverses;

    mapping(address => bool) public _metaverseNftCollections; // 1 metaverse only map with 1 nft collections -> add zone-2 always = this nft collection
    mapping(address => mapping(uint256 => bool)) _minted;// marked erc-721 id

    modifier adminOnly() {
        require(_msgSender() == _admin, Errors.ONLY_ADMIN_ALLOWED);
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), Errors.ONLY_ADMIN_ALLOWED);
        _;
    }

    modifier creatorOnly(uint256 _id) {
        require(_tokens[_id]._creator == _msgSender(), Errors.ONLY_CREATOR);
        _;
    }

    function initialize(
        string memory name,
        string memory symbol,
        string memory baseUri,
        address admin,
        address paramsAddress
    ) initializer public {
        require(admin != address(0) && paramsAddress != address(0), Errors.INV_ADD);
        __ERC721PresetMinterPauserAutoId_init(name, symbol, baseUri);
        _paramsAddr = paramsAddress;
        _admin = admin;

        // set role for admin address
        grantRole(DEFAULT_ADMIN_ROLE, _admin);
        grantRole(MINTER_ROLE, _admin);
        grantRole(PAUSER_ROLE, _admin);
        // revoke role for sender
        revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
        revokeRole(MINTER_ROLE, msg.sender);
        revokeRole(PAUSER_ROLE, msg.sender);
    }

    function changeAdmin(address _newAdmin) public adminOnly {
        require(_newAdmin != address(0), Errors.INV_ADD);
        address _previousAdmin = _admin;
        _admin = _newAdmin;

        grantRole(DEFAULT_ADMIN_ROLE, _admin);
        grantRole(MINTER_ROLE, _admin);
        grantRole(PAUSER_ROLE, _admin);

        revokeRole(DEFAULT_ADMIN_ROLE, _previousAdmin);
        revokeRole(MINTER_ROLE, _previousAdmin);
        revokeRole(PAUSER_ROLE, _previousAdmin);
    }

    function changeMetaverseLayoutAddr(address newAddr) public adminOnly {
        require(newAddr != address(0), Errors.INV_ADD);
        address _prevAddr = _metaverseLayoutAddr;
        _metaverseLayoutAddr = newAddr;

    }

    function changeMetaverseOwner(uint256 _metaverseId, address _add) external {
        require(_metaverses[_metaverseId]._metaverseOwner == msg.sender && _add != address(0), Errors.INV_ADD);
        _metaverses[_metaverseId]._metaverseOwner = _add;
    }

    function getZone(uint256 metaverseId, uint256 zoneIndex) external returns (SharedStruct.ZoneInfo memory) {
        return _metaverses[metaverseId]._metaverseZones[zoneIndex];
    }

    // TODO:
    function validateSpaceData(uint256 metaverseId, uint256 zoneIndex, uint256 spaceIndex, SharedStruct.SpaceInfo memory spaceData) internal returns (uint256) {
        uint256 _spaceId = (metaverseId * (10 ** 9) + zoneIndex) * (10 ** 9) + (spaceIndex + 1);
        if (_tokens[_spaceId]._init) {
            return 0;
        }
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
        require(_metaverses[metaverseId]._metaverseOwner == address(0), Errors.EXIST_METAVERSE);
        require(zone.typeZone > 0);
        if (zone.typeZone == 2) {
            require(_metaverseNftCollections[zone.collAddr] == false, Errors.EXIST_METAVERSE);
            require(zone.zoneIndex == 2, Errors.INV_ZONE);
            // marked nft-gated
            _metaverseNftCollections[zone.collAddr] = true;
            // set owner is admin
            _metaverses[metaverseId]._metaverseOwner = _admin;
        } else if (zone.typeZone == 3) {
            require(zone.zoneIndex == 3, Errors.INV_ZONE);
            // set owner is creator who is called from metaverse layout
            require(creator != address(0));
            _metaverses[metaverseId]._metaverseOwner = creator;
        }
        // set zone
        _metaverses[metaverseId]._metaverseZones[zone.zoneIndex] = zone;

        // loop for setting space info
        for (uint256 i = 0; i < spaceDatas.length; i++) {
            uint256 spaceId = validateSpaceData(metaverseId, zone.zoneIndex, i, spaceDatas[i]);
            require(spaceId > 0);
            _tokens[spaceId]._spaceData = spaceDatas[i];
            // update size of metaverse
            _metaverses[metaverseId]._size += 1;
        }

        emit InitMetaverse(metaverseId, _metaverses[metaverseId]._metaverseOwner, zone, spaceDatas);
    }

    function extendMetaverse(
        uint256 metaverseId,
        SharedStruct.ZoneInfo memory zone,
        SharedStruct.SpaceInfo[] memory spaceDatas)
    external {
        // require init from template layout contract. Note: metaverse layout had to check msg.sender is owner of this metaverse
        require(msg.sender == _metaverseLayoutAddr, Errors.INV_LAYOUT);

        require(zone.typeZone > 0 && zone.zoneIndex > 0);
        require(_metaverses[metaverseId]._metaverseOwner != address(0), Errors.N_EXIST_METAVERSE);
        require(_metaverses[metaverseId]._metaverseZones[zone.zoneIndex].typeZone != 0);

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
    function mint(address mintTo, address creator, uint256 metaverseId, uint256 zoneIndex, uint256 spaceId, string memory uri, bytes memory data) external {
        // require mint from template layout contract
        require(msg.sender == _metaverseLayoutAddr, Errors.INV_LAYOUT);

        // TODO verify spaceId

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

        _tokens[spaceId]._creator = creator;
        _safeMint(mintTo, spaceId);
        if (bytes(uri).length > 0) {
            _tokens[spaceId]._customUri = uri;
        }

        emit Mint(mintTo, creator, metaverseId, zoneIndex, spaceId, uri, data);
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

    function _setCreator(address _to, uint256 _id) internal creatorOnly(_id) {
        _tokens[_id]._creator = _to;
    }

    function setCreator(
        address _to,
        uint256[] memory _ids
    ) public {
        require(_to != address(0), Errors.INV_ADD);

        _grantRole(MINTER_ROLE, _to);
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            _setCreator(_to, id);
        }
    }

    /** @dev EIP2981 royalties implementation. */
    struct RoyaltyInfo {
        address recipient;
        uint24 amount;
        bool isValue;
    }

    mapping(uint256 => RoyaltyInfo) public royalties;

    function setTokenRoyalty(
        uint256 _tokenId,
        address _recipient,
        uint256 _value
    ) public adminOnly {
        require(_value <= 10000, Errors.REACH_MAX);
        royalties[_tokenId] = RoyaltyInfo(_recipient, uint24(_value), true);
    }

    // EIP2981 standard royalties return.
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view override
    returns (address receiver, uint256 royaltyAmount)
    {
        RoyaltyInfo memory royalty = royalties[_tokenId];
        if (royalty.isValue) {
            receiver = royalty.recipient;
            royaltyAmount = (_salePrice * royalty.amount) / 10000;
        } else {
            receiver = _tokens[_tokenId]._creator;
            royaltyAmount = (_salePrice * 500) / 10000;
        }
    }
}