import * as dotenv from 'dotenv';

import {ethers} from "ethers";
import * as fs from "fs";
import {keccak256} from "ethers/lib/utils";
import {GalaxyData} from "./galaxydata";
import Web3 from "web3";
import {createAlchemyWeb3} from "@alch/alchemy-web3";

const hardhatConfig = require("../../../hardhat.config");

(async () => {
    try {
        if (process.env.NETWORK != "mumbai") {
            console.log("wrong network");
            return;
        }
        const data = new GalaxyData(process.env.NETWORK, process.env.PRIVATE_KEY, process.env.PUBLIC_KEY);
        const args = process.argv.slice(2)
        const traits = await data.getTraits(args[0]);
        const traitsData = await data.getTraitsAvailableValues(args[0]);
        const web3 = createAlchemyWeb3(hardhatConfig.networks[hardhatConfig.defaultNetwork].url);
        let result: any = {};
        for (let i = 0; i < traits.length; i++) {
            result[web3.utils.hexToString(traits[i])] = [];
            for (let j = 0; j < traitsData[i].length; j++) {
                result[web3.utils.hexToString(traits[i])].push(web3.utils.hexToString(traitsData[i][j]));
            }
        }
        console.log(result);
    } catch (e) {
        // Deal with the fact the chain failed
        console.log(e);
    }
})();