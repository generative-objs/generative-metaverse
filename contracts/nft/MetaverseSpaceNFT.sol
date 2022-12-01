// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../lib/helpers/Errors.sol";
import "../lib/helpers/Utils.sol";
import "../lib/configurations/MetaverseLayoutNFTConfiguration.sol";
import "../interfaces/IMetaverseLayoutNFT.sol";
import "../interfaces/IParameterControl.sol";
import "../interfaces/IMetaverseSpaceNFT.sol";
import "../operator-filter-registry/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import "../lib/structs/Space.sol";
import "../lib/structs/Metaverse.sol";

contract MetaverseSpaceNFT is Initializable, ERC721PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable,
IERC2981Upgradeable, IMetaverseSpaceNFT,
DefaultOperatorFiltererUpgradeable {
    // admin feature
    address public _admin;
    address public _paramsAddr;
    address public _metaverseLayoutAddr;
    // base uri
    string public _uri;

    mapping(uint256 => Space.SpaceInfo) public _spaceTokens;
    mapping(uint256 => Space.MetaverseInfo) public _metaverses; // clone data from parent metaverse
    mapping(address => mapping(uint256 => bool)) _minted;// marked erc-721 id

    function initialize(
        string memory name,
        string memory symbol,
        string memory baseUri,
        address admin,
        address paramsAddress,
        address layoutAddr
    ) initializer public {
        require(admin != address(0) && paramsAddress != address(0) && layoutAddr != address(0), Errors.INV_ADD);
        __ERC721_init(name, symbol);
        _paramsAddr = paramsAddress;
        _admin = admin;
        _metaverseLayoutAddr = layoutAddr;

        __Ownable_init();
        __DefaultOperatorFilterer_init();
        __ReentrancyGuard_init();
        __ERC721Pausable_init();
    }

    function changeAdmin(address _newAdmin) public {
        require(msg.sender == _admin && _newAdmin != address(0), Errors.INV_ADD);
        address _previousAdmin = _admin;
        _admin = _newAdmin;
    }

    function pause() external {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        _pause();
    }

    function unpause() external {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        _unpause();
    }

    // initMetaverse: init metaverse and had to call from metaverse layout contract
    // this func only can be called once. To extend metaverse, need to call function extendMetaverse
    function initMetaverse(uint256 metaverseId, Metaverse.MetaverseInfo memory metaverseInfo) external {
        // require init from template layout contract
        require(msg.sender == _metaverseLayoutAddr, Errors.INV_LAYOUT);

        // clone data
        _metaverses[metaverseId]._creator = metaverseInfo._creator;
        _metaverses[metaverseId]._fee = metaverseInfo._fee;
        _metaverses[metaverseId]._feeTokenAddr = metaverseInfo._feeTokenAddr;
        _metaverses[metaverseId]._nftGated = metaverseInfo._zones[0]._collAddr;

        // TODO: 
        // loop for setting space info
        /*        _metaverses[metaverseId]._size = spaceDatas.length;
                for (uint256 i = 0; i < spaceDatas.length; i++) {
                    uint256 spaceId = validateSpaceData(metaverseId, zone.zoneIndex, i, spaceDatas[i]);
                    require(spaceId > 0);
                    _tokens[spaceId]._spaceData = spaceDatas[i];
                }*/
    }

    function extendMetaverse(
        uint256 metaverseId,
        Metaverse.ZoneInfo memory zone)
    external {
        // require init from template layout contract. Note: metaverse layout had to check msg.sender is owner of this metaverse
        require(msg.sender == _metaverseLayoutAddr, Errors.INV_LAYOUT);

        // loop for setting space info
        /*        uint256 currentSize = _metaverses[metaverseId]._size;
                for (uint256 i = currentSize; i < spaceDatas.length + currentSize; i++) {
                    uint256 spaceId = validateSpaceData(metaverseId, zone.zoneIndex, i, spaceDatas[i - currentSize]);
                    require(spaceId > 0);
                    _tokens[spaceId]._spaceData = spaceDatas[i];
         update size of metaverse
                    _metaverses[metaverseId]._size += 1;
                }*/

    }

    /* @URI: 
    */
    function _baseURI() internal view override returns (string memory) {
        return "";
    }

    function tokenURI(uint256 _spaceId) override public view returns (string memory) {
        bytes memory customUriBytes = bytes(_spaceTokens[_spaceId]._customUri);
        if (customUriBytes.length > 0) {
            return _spaceTokens[_spaceId]._customUri;
        } else {
            string memory baseURI = _baseURI();
            return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, StringsUpgradeable.toString(_spaceId))) : "";
        }
    }

    /* @TRAITS: Get data for render
    */
    function getParameterValues(uint256 metaverseId) public view returns (uint256) {
        return 0;
    }

    /* @MINT: mint a space as token
    */
    function paymentMint(address _creator, address _feeToken, uint256 _fee) internal {
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
                (bool success,) = _creator.call{value : _fee - (_fee * operationFee / Metaverse.PERCENT_MIN)}("");
                require(success);
                // pay for host metaverse parent
                (success,) = _metaverseLayoutAddr.call{value : _fee * operationFee / Metaverse.PERCENT_MIN}("");
            } else {
                IERC20Upgradeable tokenERC20 = IERC20Upgradeable(_feeToken);
                // transfer all fee erc-20 token to this contract
                require(tokenERC20.transferFrom(msg.sender, address(this), _fee));

                // pay for owner project
                require(tokenERC20.transfer(_creator, _fee - (_fee * operationFee / Metaverse.PERCENT_MIN)));
                // pay for host metaverse parent
                require(tokenERC20.transfer(_metaverseLayoutAddr, _fee * operationFee / Metaverse.PERCENT_MIN));
            }
        }
    }

    function mint(uint256 metaverseId, uint256 spaceId, string memory uri) external {
        // verify metaverse
        require(_metaverses[metaverseId]._creator != address(0x0), Errors.INV_ADD);
        // TODO verify spaceId

        // payment
        paymentMint(_metaverses[metaverseId]._creator, _metaverses[metaverseId]._feeTokenAddr, _metaverses[metaverseId]._fee);

        // create space data
        _spaceTokens[spaceId]._metaverseId = metaverseId;
        // and mint to token
        _safeMint(msg.sender, spaceId);

        if (bytes(uri).length > 0) {
            _spaceTokens[spaceId]._customUri = uri;
        }
    }

    function mintByToken(uint256 metaverseId, uint256 spaceId, string memory uri, bytes memory data) external {
        // verify metaverse
        require(_metaverses[metaverseId]._creator != address(0x0), Errors.INV_ADD);

        // TODO verify spaceId

        // TODO for https://delegate.cash/
        if (_metaverses[metaverseId]._nftGated != address(0)) {
            // check nft holder
            IERC721Upgradeable erc721 = IERC721Upgradeable(_metaverses[metaverseId]._nftGated);
            // get token erc721 id from data
            uint256 _erc721Id = Utils.sliceUint(data, 0);
            // check owner token id
            require(erc721.ownerOf(_erc721Id) == msg.sender, Errors.INV_ADD);
            // check token not minted 
            require(!_minted[_metaverses[metaverseId]._nftGated][_erc721Id], "M");
            // marked this erc721 token id is minted ticket
            _minted[_metaverses[metaverseId]._nftGated][_erc721Id] = true;
        }

        // payment
        paymentMint(_metaverses[metaverseId]._creator, _metaverses[metaverseId]._feeTokenAddr, _metaverses[metaverseId]._fee);

        // create space data
        _spaceTokens[spaceId]._metaverseId = metaverseId;
        // and mint to token
        _safeMint(msg.sender, spaceId);

        if (bytes(uri).length > 0) {
            _spaceTokens[spaceId]._customUri = uri;
        }
    }

    /* @dev EIP2981 royalties implementation. 
    // EIP2981 standard royalties return.
    */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view override
    returns (address receiver, uint256 royaltyAmount)
    {
        receiver = _metaverses[_spaceTokens[_tokenId]._metaverseId]._creator;
        royaltyAmount = (_salePrice * 500) / Metaverse.PERCENT_MIN;
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
