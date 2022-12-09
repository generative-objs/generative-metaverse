pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "../lib/structs/Galaxy.sol";
import "../lib/helpers/Errors.sol";
import "../lib/helpers/Base64.sol";
import "../interfaces/IGalaxyData.sol";
import "../interfaces/IParameterControl.sol";

contract GalaxyData is OwnableUpgradeable, IGalaxyData {
    address public _admin;
    address public _paramAddr;

    mapping(bytes => bytes[]) public _traitsAvailableValues;
    bytes[] public _traits = [bytes("T1"), "T2", "T3"];

    function initialize(address admin, address paramAddr) initializer public {
        _admin = admin;
        _paramAddr = paramAddr;

        __Ownable_init();

        // TODO
        // init trait 0
        _traitsAvailableValues[_traits[0]] = new bytes[](5);
        // init trait 1
        _traitsAvailableValues[_traits[1]] = new bytes[](5);
        // init trait 2
        _traitsAvailableValues[_traits[2]] = new bytes[](5);
    }

    function addTrait(bytes memory name, bytes[] memory values) external {
        require(msg.sender == _admin, Errors.INV_ADD);

        // push trait
        _traits.push(name);
        // apply available values for trait
        _traitsAvailableValues[_traits[_traits.length - 1]] = new bytes[](values.length);
        for (uint256 i = 0; i < values.length; i++) {
            _traitsAvailableValues[_traits[_traits.length - 1]][i] = values[i];
        }
    }

    function deleteTrait(uint256 index) external {
        require(msg.sender == _admin, Errors.INV_ADD);
        // delete available values
        delete _traitsAvailableValues[_traits[index]];
        // delete trait
        delete _traits[index];
    }

    function editTrait(uint256 index, bytes memory name) external {
        require(msg.sender == _admin, Errors.INV_ADD);
        // change name of trait
        _traits[index] = name;
    }

    function addTraitValue(uint256 indexTrait, bytes memory value) external {
        require(msg.sender == _admin, Errors.INV_ADD);
        // push a new available value for trait
        _traitsAvailableValues[_traits[indexTrait]].push(value);
    }

    function deleteTraitValue(uint256 indexTrait, uint256 indexValue) external {
        require(msg.sender == _admin, Errors.INV_ADD);
        // delete an available value for trait
        delete _traitsAvailableValues[_traits[indexTrait]][indexValue];
    }

    function getTraits() external view returns (bytes[] memory traitsName) {
        return _traits;
    }

    function getTraitsAvailableValues() external view returns (bytes[][] memory) {
        bytes[][] memory result = new bytes[][](_traits.length);
        for (uint256 i = 0; i < _traits.length; i++) {
            result[i] = _traitsAvailableValues[_traits[i]];
        }
        return result;
    }

    function tokenURI(uint256 seed) external view returns (string memory result) {
        result = string(
            abi.encodePacked('data:application/json;base64,',
            Base64.encode(abi.encodePacked(''))
            )
        );
    }

    function tokenHTML(uint256 seed) external view returns (string memory result) {
        IParameterControl param = IParameterControl(_paramAddr);
        result = string(abi.encodePacked("<html><head><meta charset='UTF-8'><style>html,body,svg{margin:0;padding:0; height:100%;text-align:center;}</style>",
            param.get("three.js"), // load threejs lib here
            "<script>let seed = ", StringsUpgradeable.toString(seed), ";</script></head><body>",
            "<div id='container-el'></div>",
            "<script>//TODO running script</script>",
            "</body></html>"
            ));
    }

    function tokenTraits(uint256 seed) external view returns (string memory result) {
        // TODO with seed
        string memory traits = "";
        for (uint256 i = 0; i < _traits.length; i++) {
            traits = string(abi.encodePacked(traits, '{"trait_type":"', _traits[i], '","value":"', _traits[i][0], '"}'));
            if (i < _traits.length - 1) {
                traits = string(abi.encodePacked(traits, ','));
            }
        }
        result = string(abi.encodePacked('"attributes":[', traits, ']'));
    }
}
