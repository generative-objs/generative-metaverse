// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.12;

library Errors {
    enum ReturnCode {
        SUCCESS,
        FAILED
    }

    // common errors
    string public constant INV_ADD = "100";
    string public constant ONLY_ADMIN_ALLOWED = "101";
    string public constant ONLY_CREATOR = "102";

    // validate errors
    string public constant REACH_MAX = "200";
    string public constant INV_LAYOUT = "201";
    string public constant EXIST_METAVERSE = "202";
    string public constant N_EXIST_METAVERSE = "203";
    string public constant INV_ZONE = "204";
    string public constant INV_PARAMS = "205";
}