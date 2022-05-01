require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("hardhat-spdx-license-identifier");
require('hardhat-deploy');
require ('hardhat-abi-exporter');
require("@nomiclabs/hardhat-ethers");
require("dotenv/config")
const { TOKENS } = require('./config/tokens.js');

let accounts = [];
var fs = require("fs");
var read = require('read');
var util = require('util');
const keythereum = require("keythereum");
const prompt = require('prompt-sync')();
(async function() {
    try {
        const root = '.keystore';
        var pa = fs.readdirSync(root);
        for (let index = 0; index < pa.length; index ++) {
            let ele = pa[index];
            let fullPath = root + '/' + ele;
		    var info = fs.statSync(fullPath);
            //console.dir(ele);
		    if(!info.isDirectory() && ele.endsWith(".keystore")){
                const content = fs.readFileSync(fullPath, 'utf8');
                const json = JSON.parse(content);
                const password = prompt('Input password for 0x' + json.address + ': ', {echo: '*'});
                //console.dir(password);
                const privatekey = keythereum.recover(password, json).toString('hex');
                //console.dir(privatekey);
                accounts.push('0x' + privatekey);
                //console.dir(keystore);
		    }
	    }
    } catch (ex) {
    }
    try {
        const file = '.secret';
        var info = fs.statSync(file);
        if (!info.isDirectory()) {
            const content = fs.readFileSync(file, 'utf8');
            let lines = content.split('\n');
            for (let index = 0; index < lines.length; index ++) {
                let line = lines[index];
                if (line == undefined || line == '') {
                    continue;
                }
                if (!line.startsWith('0x') || !line.startsWith('0x')) {
                    line = '0x' + line;
                }
                accounts.push(line);
            }
        }
    } catch (ex) {
    }
})();

module.exports = {
    defaultNetwork: "hardhat",
    abiExporter: {
        path: "./abi",
        clear: false,
        flat: true,
        // only: [],
        // except: []
    },
    namedAccounts: {
        deployer: {
            default: 0,
            97: '0xa355A0BFe235b9a1EA304A9dAFeafA113f7d2CAa',
            43114: '0xa355A0BFe235b9a1EA304A9dAFeafA113f7d2CAa',
        },
        admin: {
            default: 1,
            97: '0xa355A0BFe235b9a1EA304A9dAFeafA113f7d2CAa',
            43114: '0xa355A0BFe235b9a1EA304A9dAFeafA113f7d2CAa',
        },
        devAddr: {
            default: 2,
            97: '0xa355A0BFe235b9a1EA304A9dAFeafA113f7d2CAa',
            43114: '0xa355A0BFe235b9a1EA304A9dAFeafA113f7d2CAa',
        },
        ecoAddr: {
            default: 2,
            97: '0xD6cE8D826423dcCE1760A3B688D21F3CB6E92452',
            43114: '0xD6cE8D826423dcCE1760A3B688D21F3CB6E92452',
        },        
        reserveAddr: {
            default: 3,
            97: '0x992f3898156c61B12fAa3bCeF24076DFBB2de053',
            43114: '0x992f3898156c61B12fAa3bCeF24076DFBB2de053',
        },
        feeTo: {
            default: '0xD6cE8D826423dcCE1760A3B688D21F3CB6E92452',
            97: '0xD6cE8D826423dcCE1760A3B688D21F3CB6E92452',
            43114: '0xD6cE8D826423dcCE1760A3B688D21F3CB6E92452',
        },
        USDT: {
            default: '0xc7198437980c041c805A1EDcbA50c1Ce5db95118',
            97: '0xc7198437980c041c805A1EDcbA50c1Ce5db95118',
            43114: '0xc7198437980c041c805A1EDcbA50c1Ce5db95118',
        },
        WAVAX: {
            default: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
            97: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
            43114: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
        }
    },
    networks: {
        mainnet: {
            url: `https://api.avax.network/ext/bc/C/rpc`,
            accounts: accounts,
            //gasPrice: 1.3 * 1000000000,
            chainId: 43114,
            gasMultiplier: 1.5,
        },
        test: {
            url: `https://data-seed-prebsc-1-s1.binance.org:8545`,
            accounts: accounts,
            //gasPrice: 1.3 * 1000000000,
            chainId: 97,
            tags: ["test"],
        },
        hardhat: {
            forking: {
                enabled: true,
                url: `https://bsc-dataseed1.defibit.io/`
                //url: `https://bsc-dataseed1.ninicoin.io/`
                //url: `https://bsc-dataseed3.binance.org/`
                //url: `https://data-seed-prebsc-1-s1.binance.org:8545`
            },
            live: true,
            saveDeployments: true,
            tags: ["test", "local"],
            chainId: 56,
            timeout: 2000000,
        }
    },
    solidity: {
        compilers: [
            {
                version: "0.6.12",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    spdxLicenseIdentifier: {
        overwrite: true,
        runOnCompile: true,
    },
    mocha: {
        timeout: 2000000,
    },
    etherscan: {
     apiKey: process.env.BSC_API_KEY,
   }
};

(function() {
    Object.assign(module.exports.namedAccounts, TOKENS);
})()
