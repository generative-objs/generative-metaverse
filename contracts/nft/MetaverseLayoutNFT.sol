// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.12;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../lib/configurations/MetaverseLayoutNFTConfiguration.sol";

import "../interfaces/IMetaverseLayoutNFT.sol";
import "../interfaces/IMetaverseSpaceNFT.sol";
import "../interfaces/IParameterControl.sol";
import "../interfaces/ICallback.sol";

import "../lib/helpers/Errors.sol";
import "../lib/helpers/Errors.sol";

import "../operator-filter-registry/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import "../lib/structs/Metaverse.sol";
import "../lib/structs/Space.sol";


contract MetaverseLayoutNFT is Initializable, ERC721PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable,
IMetaverseLayoutNFT, IERC2981Upgradeable, ICallback,
DefaultOperatorFiltererUpgradeable
{
    // admin feature
    address public _admin;
    address public _paramsAddr;
    address public _oracleServiceAddr;
    // base uri
    string public _uri;
    // metaverse info 
    mapping(uint256 => Metaverse.MetaverseInfo) public _metaverses;
    // 1 metaverse only map with 1 nft collections -> add zone-2 always = this nft collection
    mapping(address => bool) public _metaverseNftCollections;

    function initialize(
        string memory name,
        string memory symbol,
        address admin,
        address paramsAddress
    ) initializer public {
        require(admin != address(0), Errors.INV_ADD);
        require(paramsAddress != address(0), Errors.INV_ADD);
        __ERC721_init(name, symbol);
        _paramsAddr = paramsAddress;
        _admin = admin;

        __Ownable_init();
        __DefaultOperatorFilterer_init();
        __ReentrancyGuard_init();
        __ERC721Pausable_init();
    }

    function changeAdmin(address newAdm) external {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);

        address _previousAdmin = _admin;
        _admin = newAdm;
    }

    function pause() external {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        _pause();
    }

    function unpause() external {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        _unpause();
    }

    function withdraw(address erc20Addr, uint256 amount) external nonReentrant {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        bool success;
        if (erc20Addr == address(0x0)) {
            require(address(this).balance >= amount);
            (success,) = msg.sender.call{value : amount}("");
            require(success);
        } else {
            IERC20Upgradeable tokenERC20 = IERC20Upgradeable(erc20Addr);
            // transfer erc-20 token
            require(tokenERC20.transfer(msg.sender, amount));
        }
    }

    /* @TRAITS: Get data for render
    */
    function getParameterValues(uint256 metaverseId) public view returns (uint256) {
        return 0;
    }


    /* @URI: control uri
    */

    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    function changeBaseURI(string memory baseURI) public {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        _uri = baseURI;
    }

    function tokenURI(uint256 metaverseId) override public view returns (string memory) {
        bytes memory customUriBytes = bytes(_metaverses[metaverseId]._customUri);
        if (customUriBytes.length > 0) {
            return _metaverses[metaverseId]._customUri;
        } else {
            string memory baseURI = _baseURI();
            return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, StringsUpgradeable.toString(metaverseId))) : "";
        }
    }

    /* @MINT : Mint / Init metaverse
    // create metaverse layout and init metaverse in MetaverseNFT
    */
    function paymentMint(Metaverse.ZoneInfo memory zone) internal {
        if (msg.sender != _admin) {
            IParameterControl _p = IParameterControl(_paramsAddr);
            // at least require value 1ETH
            uint256 operationFee = _p.getUInt256(MetaverseLayoutNFTConfiguration.CREATE_METAVERSE_FEE);
            if (operationFee > 0) {
                address operationFeeToken = _p.getAddress(MetaverseLayoutNFTConfiguration.FEE_TOKEN);
                if (!(operationFeeToken == address(0))) {
                    IERC20Upgradeable tokenERC20 = IERC20Upgradeable(operationFeeToken);
                    // transfer erc-20 token to this contract
                    require(tokenERC20.transferFrom(
                            msg.sender,
                            address(this),
                            operationFee
                        ));
                } else {
                    require(msg.value >= operationFee);
                }
            }
        }
    }

    function mint(uint256 metaverseId,
        address spaceNFT,
        address feeToken,
        uint256 fee,
        string memory algo,
        Metaverse.ZoneInfo memory zone
    ) public nonReentrant payable {
        // payment
        IParameterControl _p = IParameterControl(_paramsAddr);
        paymentMint(zone);

        // check metaverse id
        require(_metaverses[metaverseId]._creator == address(0), Errors.EXIST_METAVERSE);
        // check space collection
        require(spaceNFT != address(0), Errors.INV_ADD);
        IMetaverseSpaceNFT metaverseSpaceNFT = IMetaverseSpaceNFT(spaceNFT);
        require(address(metaverseSpaceNFT).code.length > 0);
        // check zone
        require(zone._size > 0);

        // init metaverse
        _metaverses[metaverseId]._creator = msg.sender;
        _metaverses[metaverseId]._fee = fee;
        _metaverses[metaverseId]._feeTokenAddr = feeToken;
        _metaverses[metaverseId]._algo = algo;
        _metaverses[metaverseId]._spaceAddr = spaceNFT;
        if (zone._collAddr != address(0x0)) {
            _metaverses[metaverseId]._creator = _admin;
        } else {
            _metaverses[metaverseId]._creator = msg.sender;
        }
        _metaverses[metaverseId]._zones.push(zone);
        // send init to space collection

        metaverseSpaceNFT.initMetaverse(metaverseId, _metaverses[metaverseId]);
        _safeMint(msg.sender, metaverseId);
    }

    function extendMetaverse(
        uint256 metaverseId,
        Metaverse.ZoneInfo memory zone
    ) external {
        require(msg.sender == ownerOf(metaverseId), Errors.INV_ADD);
        // check metaverse id
        require(_metaverses[metaverseId]._creator == address(0), Errors.EXIST_METAVERSE);
        // check zone
        require(zone._size > 0);
        if (_metaverses[metaverseId]._zones[_metaverses[metaverseId]._zones.length - 1]._collAddr != address(0x0)) {
            if (zone._collAddr != address(0x0)) {
                require(zone._collAddr == _metaverses[metaverseId]._zones[_metaverses[metaverseId]._zones.length - 1]._collAddr, Errors.INV_ZONE);
            }
        }

        _metaverses[metaverseId]._zones.push(zone);
        IMetaverseSpaceNFT metaverseNFT = IMetaverseSpaceNFT(_metaverses[metaverseId]._spaceAddr);
        // send extend to space collection
        metaverseNFT.extendMetaverse(metaverseId, zone);
    }

    function setAlgo(uint256 metaverseId, string memory metaverseAlgo) external {
        require(msg.sender == _metaverses[metaverseId]._creator, Errors.INV_ADD);
        _metaverses[metaverseId]._algo = metaverseAlgo;
    }

    function setCustomUri(uint256 metaverseId, string memory uri) external {
        require(msg.sender == _metaverses[metaverseId]._creator, Errors.INV_ADD);
        _metaverses[metaverseId]._customUri = uri;
    }

    /* @Royalty: EIP2981 royalties implementation. 
    // EIP2981 standard royalties return.
    */

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view override
    returns (address receiver, uint256 royaltyAmount)
    {
        receiver = _metaverses[_tokenId]._creator;
        royaltyAmount = (_salePrice * 500) / Metaverse.PERCENT_MIN;
    }


    /* @Opensea: opensea operator filter registry
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

    /* @Oracle:
    */

    function changeOracle(address oracle) external {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        require(oracle != address(0), Errors.INV_ADD);
        _oracleServiceAddr = oracle;
    }

    function fulfill(bytes32 requestId, bytes memory data) external {
        require(msg.sender == _oracleServiceAddr, Errors.INV_ADD);
        emit FulfillEvent(requestId, data);
        // TODO: do something
    }
}
