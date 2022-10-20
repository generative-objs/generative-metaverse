// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.12;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../interfaces/IMetaverseLayoutNFT.sol";
import "../lib/helpers/Errors.sol";
import "../lib/helpers/Utils.sol";
import "../lib/helpers/SharedStruct.sol";
import "../interfaces/IMetaverseNFT.sol";
import "../interfaces/IParameterControl.sol";
import "../lib/helpers/SharedStruct.sol";
import "../lib/configurations/MetaverseLayoutNFTConfiguration.sol";
import "../lib/helpers/BoilerplateParam.sol";

contract MetaverseLayoutNFT is Initializable, ERC721PresetMinterPauserAutoIdUpgradeable, ReentrancyGuardUpgradeable, IMetaverseLayoutNFT, IERC2981Upgradeable {
    // super admin
    address public _admin;
    // parameter control address
    address public _paramsAddress;

    struct MetaverseInfo {
        uint256 _fee; // fee for mint space from layout default frees
        address _feeTokenAddr;// fee currency for mint space from layout default is native token
        address _creator; // creator list for project, using for royalties
        string _customUri; // project info nft view
        string _projectName; // name of project
        address _minterNFTInfo;// map projectId ->  NFT collection address mint from project
        uint256 _mintTotalSupply; // total supply minted on metaverse
        string _script; // script render: 1/ simplescript 2/ ipfs:// protocol
        uint32 _scriptType; // script type: python, js, ....
        BoilerplateParam.ParamsOfProject _paramsTemplate; // struct contains list params of project and random seed(registered) in case mint nft from project
    }

    mapping(uint256 => MetaverseInfo) public _metaverses;


    function initialize(
        string memory name,
        string memory symbol,
        string memory baseUri,
        address admin,
        address paramsAddress
    ) initializer public {
        require(admin != address(0), Errors.INV_ADD);
        require(paramsAddress != address(0), Errors.INV_ADD);
        __ERC721PresetMinterPauserAutoId_init(name, symbol, baseUri);
        _paramsAddress = paramsAddress;
        _admin = admin;
        // set role for admin address
        grantRole(DEFAULT_ADMIN_ROLE, _admin);

        // revoke role for sender
        revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function changeAdmin(address newAdm) external {
        require(_msgSender() == _admin, Errors.ONLY_ADMIN_ALLOWED);
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), Errors.ONLY_ADMIN_ALLOWED);

        address _previousAdmin = _admin;
        _admin = newAdm;

        grantRole(DEFAULT_ADMIN_ROLE, _admin);

        revokeRole(DEFAULT_ADMIN_ROLE, _previousAdmin);
    }

    // disable old mint
    function mint(address to) public override {}
    // mint:
    // create metaverse layout and init metaverse in MetaverseNFT
    function mint(address to, uint256 metaverseId, MetaverseInfo memory project, BoilerplateParam.ParamsOfProject calldata paramsTemplate, SharedStruct.ZoneInfo memory zone, SharedStruct.SpaceInfo[] memory spaceDatas) public nonReentrant payable returns (uint256) {
        require(!_exists(metaverseId), Errors.EXIST_METAVERSE);

        // payment
        IParameterControl _p = IParameterControl(_paramsAddress);
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

        if (bytes(project._customUri).length > 0) {
            _metaverses[metaverseId]._customUri = project._customUri;
        }
        require(bytes(project._projectName).length > 0);
        _metaverses[metaverseId]._projectName = project._projectName;
        _metaverses[metaverseId]._creator = msg.sender;

        // fee
        _metaverses[metaverseId]._fee = project._fee;
        _metaverses[metaverseId]._feeTokenAddr = project._feeTokenAddr;

        // script
        _metaverses[metaverseId]._script = project._script;
        _metaverses[metaverseId]._scriptType = project._scriptType;
        _metaverses[metaverseId]._paramsTemplate = paramsTemplate;

        _safeMint(to, metaverseId);
        // TODO call init metaverse to MetaverseNFT 
        IMetaverseNFT metaverseNFT = IMetaverseNFT(address(0));
        metaverseNFT.initMetaverse(metaverseId, msg.sender, zone, spaceDatas);
        return metaverseId;
    }

    function mintSpace(IMetaverseLayoutNFT.MintRequest memory mintBatch) public nonReentrant payable {
        MetaverseInfo memory project = _metaverses[mintBatch._metaverseId];
        require(mintBatch._uriBatch.length > 0
        && mintBatch._uriBatch.length == mintBatch._paramsBatch.length
            && mintBatch._spaceIdBatch.length == mintBatch._paramsBatch.length, Errors.INV_PARAMS);
        IParameterControl _p = IParameterControl(_paramsAddress);

        // get payable
        bool success;
        uint256 _mintFee = project._fee;
        if (_mintFee > 0) {
            _mintFee *= mintBatch._uriBatch.length;
            uint256 operationFee = _p.getUInt256(MetaverseLayoutNFTConfiguration.MINT_NFT_FEE);
            if (operationFee == 0) {
                operationFee = 500;
                // default 5% getting, 95% pay for owner of project
            }
            if (project._feeTokenAddr == address(0)) {
                require(msg.value >= _mintFee);

                // pay for owner project
                (success,) = ownerOf(mintBatch._metaverseId).call{value : _mintFee - (_mintFee * operationFee / 10000)}("");
                require(success);
            } else {
                IERC20Upgradeable tokenERC20 = IERC20Upgradeable(project._feeTokenAddr);
                // transfer all fee erc-20 token to this contract
                require(tokenERC20.transferFrom(
                        msg.sender,
                        address(this),
                        _mintFee
                    ));

                // pay for owner project
                require(tokenERC20.transfer(ownerOf(mintBatch._metaverseId), _mintFee - (_mintFee * operationFee / 10000)));
            }
        }

        // minting NFT to other collection by minter
        IMetaverseNFT nft = IMetaverseNFT(_metaverses[mintBatch._metaverseId]._minterNFTInfo);
        SharedStruct.ZoneInfo memory zone = nft.getZone(mintBatch._metaverseId, mintBatch._zoneIndex);
        for (uint256 i = 0; i < mintBatch._paramsBatch.length; i++) {
            require(_metaverses[mintBatch._metaverseId]._paramsTemplate._params.length == mintBatch._paramsBatch[i]._params.length, Errors.INV_PARAMS);
            bytes memory data = abi.encodePacked("");
            if (zone.typeZone == 2) {
                data = abi.encodePacked(mintBatch._spaceIdBatch[i]);
            }
            nft.mint(mintBatch._mintTo, msg.sender, mintBatch._metaverseId, mintBatch._zoneIndex, mintBatch._spaceIdBatch[i], mintBatch._uriBatch[i], data);
            // increase total supply minting on project
            project._mintTotalSupply += 1;
            _metaverses[mintBatch._metaverseId]._mintTotalSupply = project._mintTotalSupply;
        }

        emit MintSpace(msg.sender, mintBatch);
    }

    // disable burn
    function burn(uint256 tokenId) public override {}

    function exists(uint256 _id) external view returns (bool) {
        return _exists(_id);
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
    ) external {
        require(_msgSender() == _admin, Errors.ONLY_ADMIN_ALLOWED);
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), Errors.ONLY_ADMIN_ALLOWED);
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
            receiver = _metaverses[_tokenId]._creator;
            royaltyAmount = (_salePrice * 500) / 10000;
        }
    }

    // withdraw
    // only Admin can withdraw operation fee on this contract
    // receiver: receiver address
    // erc20Addr: currency address
    // amount: amount
    function withdraw(address receiver, address erc20Addr, uint256 amount) external nonReentrant {
        require(_msgSender() == _admin, Errors.ONLY_ADMIN_ALLOWED);
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), Errors.ONLY_ADMIN_ALLOWED);
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
}