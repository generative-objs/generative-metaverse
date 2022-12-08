pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../lib/structs/Metaverse.sol";
import "../lib/helpers/Errors.sol";
import "../interfaces/IGalaxyData.sol";

contract GalaxyData is OwnableUpgradeable, IGalaxyData {
    address public _admin;

    mapping(bytes => bytes[]) public _traitsAvailableValues;
    bytes[] public _traits = [bytes("T1"), "T2", "T3"];

    function initialize(address admin) initializer public {
        _admin = admin;
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
}
