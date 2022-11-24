import { Signer } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { MockContract } from 'ethereum-waffle';
import { ethers, waffle } from 'hardhat';
import { AaveV3YieldSourceHarness, AaveV3YieldSourceHarness__factory, AavePool, ATokenMintable, ERC20Mintable,} from "../typechain-types"
import IRewardsController from "../artifacts/@aave/periphery-v3/contracts/rewards/interfaces/IRewardsController.sol/IRewardsController.json";
import IPoolAddressesProvider from "../artifacts/@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol/IPoolAddressesProvider.json";
//import { IPoolAddressesProviderRegistry } from "../typechain-types";
import  IPoolAddressesProviderRegistry  from "../artifacts/@aave/core-v3/contracts/interfaces/IPoolAddressesProviderRegistry.sol/IPoolAddressesProviderRegistry.json";
import SafeERC20 from '../artifacts/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol/SafeERC20.json';

const { constants, getContractFactory, getSigners, utils } = ethers;
const { AddressZero, MaxUint256, Zero } = constants;
const { parseUnits } = utils;
const DECIMALS = 6;
const toWei = (amount: string) => parseUnits(amount, DECIMALS);

describe("AaveV3YieldPool", function () {
    
})
