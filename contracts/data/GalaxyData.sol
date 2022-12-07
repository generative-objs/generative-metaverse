pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../lib/structs/Metaverse.sol";
import "../interfaces/IGalaxyData.sol";

contract GalaxyData is OwnableUpgradeable, IGalaxyData {
    address public _admin;

    function initialize(address admin) initializer public {
        _admin = admin;
    }

    function getTraitsName() external view returns (bytes[] memory result) {
        bytes[] memory traits = new bytes[](MetaverseTraits.traitsSize);
        traits[0] = "N1";
        traits[1] = "N2";
        traits[3] = "N3";
        return traits;
    }

    function getAvailableTraits() external view returns (bytes[][] memory traits) {
        //        traits = [["1"], ["1"]];
        traits = new bytes[][](MetaverseTraits.traitsSize);
        // trait 0
        traits[0] = new bytes[](MetaverseTraits.traits_0_Size);
        traits[0][0] = "1";
        traits[0][1] = "2";
        traits[0][2] = "3";
        traits[0][3] = "4";
        traits[0][4] = "5";
        traits[0][4] = "6";

        // trait 0
        traits[1] = new bytes[](MetaverseTraits.traits_0_Size);
        traits[1][0] = "1";
        traits[1][1] = "2";
        traits[1][2] = "3";
        traits[1][3] = "4";
        traits[1][4] = "5";
        traits[1][4] = "6";
        return traits;
    }
}
