// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.12;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../interfaces/IMetaverseLayoutNFT.sol";
import "../lib/helpers/Errors.sol";
import "../lib/helpers/Utils.sol";
import "../lib/helpers/SharedStruct.sol";
import "../interfaces/IMetaverseSpaceNFT.sol";
import "../interfaces/IParameterControl.sol";
import "../lib/helpers/SharedStruct.sol";
import "../lib/configurations/MetaverseLayoutNFTConfiguration.sol";
import "../operator-filter-registry/upgradeable/DefaultOperatorFiltererUpgradeable.sol";

contract MetaverseLayoutNFT is Initializable, ERC721PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable, IMetaverseLayoutNFT, IERC2981Upgradeable, DefaultOperatorFiltererUpgradeable {
    address public _admin;
    address public _paramsAddress;
    string public _uri;
    mapping(uint256 => SharedStruct.MetaverseInfo) public _metaverses;
    mapping(address => bool) public _metaverseNftCollections; // 1 metaverse only map with 1 nft collections -> add zone-2 always = this nft collection

    function initialize(
        string memory name,
        string memory symbol,
        address admin,
        address paramsAddress
    ) initializer public {
        require(admin != address(0), Errors.INV_ADD);
        require(paramsAddress != address(0), Errors.INV_ADD);
        __ERC721_init(name, symbol);
        _paramsAddress = paramsAddress;
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

    function withdraw(address receiver, address erc20Addr, uint256 amount) external nonReentrant {
        require(msg.sender == _admin, Errors.ONLY_ADMIN_ALLOWED);
        bool success;
        if (erc20Addr == address(0x0)) {
            require(address(this).balance >= amount);
            (success,) = receiver.call{value : amount}("");
            require(success);
        } else {
            IERC20Upgradeable tokenERC20 = IERC20Upgradeable(erc20Addr);
            // transfer erc-20 token
            require(tokenERC20.transfer(receiver, amount));
        }
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

    /* @MINT: Mint/Init metaverse
    // create metaverse layout and init metaverse in MetaverseNFT
    */

    function paymentMint() internal {
        if (msg.sender != _admin) {
            IParameterControl _p = IParameterControl(_paramsAddress);
            // at least require value 1ETH
            uint256 operationFee = _p.getUInt256(MetaverseLayoutNFTConfiguration.CREATE_PROJECT_FEE);
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
        SharedStruct.ZoneInfo memory zone,
        SpaceData.SpaceInfo[] memory spaceDatas) public nonReentrant payable {
        // payment
        IParameterControl _p = IParameterControl(_paramsAddress);
        paymentMint();

        _metaverses[metaverseId]._creator = msg.sender;
        // fee
        _metaverses[metaverseId]._fee = fee;
        _metaverses[metaverseId]._feeTokenAddr = feeToken;
        // script
        _metaverses[metaverseId]._algo = algo;

        require(spaceNFT != address(0), Errors.INV_ADD);
        IMetaverseSpaceNFT metaverseSpaceNFT = IMetaverseSpaceNFT(spaceNFT);
        require(address(metaverseSpaceNFT).code.length > 0);
        _metaverses[metaverseId]._spaceAddress = spaceNFT;
        if (zone.zoneIndex == 2) {
            // marked nft-gated
            require(_metaverseNftCollections[zone.collAddr] == false, Errors.EXIST_METAVERSE);
            _metaverseNftCollections[zone.collAddr] = true;
            _metaverses[metaverseId]._creator = _admin;
        }
        
        // send init to space
        metaverseSpaceNFT.initMetaverse(metaverseId, _metaverses[metaverseId]._creator, zone, spaceDatas);
        _safeMint(msg.sender, metaverseId);
    }

    function extendMetaverse(
        uint256 metaverseId,
        SharedStruct.ZoneInfo memory zone,
        SpaceData.SpaceInfo[] memory spaceDatas)
    external {
        require(msg.sender == ownerOf(metaverseId), Errors.INV_ADD);
        IMetaverseSpaceNFT metaverseNFT = IMetaverseSpaceNFT(_metaverses[metaverseId]._spaceAddress);
        metaverseNFT.extendMetaverse(metaverseId, zone, spaceDatas);
    }

    /* @notice: EIP2981 royalties implementation. 
    // EIP2981 standard royalties return.
    */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view override
    returns (address receiver, uint256 royaltyAmount)
    {
        receiver = _metaverses[_tokenId]._creator;
        royaltyAmount = (_salePrice * 500) / 10000;
    }


    /* @notice: opensea operator filter registry
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