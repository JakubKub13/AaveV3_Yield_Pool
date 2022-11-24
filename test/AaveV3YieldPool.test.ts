import { Signer } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { MockContract } from 'ethereum-waffle';
import { ethers, waffle } from 'hardhat';
import { AaveV3YieldPool, AaveV3YieldPool__factory, AavePool, ATokenMintable, ERC20Mintable,} from "../typechain-types"
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
    let contractsOwner: Signer;
    let yieldPoolOwner: SignerWithAddress;
    let wallet2: SignerWithAddress;
    let attacker: SignerWithAddress;
    let aToken: ATokenMintable;
    let rewardsController: MockContract;
    let pool: AavePool;
    let poolAddressesProvider: MockContract;
    let poolAddressesProviderRegistry: MockContract;
    let aaveV3YieldPool: AaveV3YieldPool
    let erc20Token: MockContract;
    let usdcToken: ERC20Mintable;

    let constructorTest = false;

    const deployAaveV3YieldPool = async (
        aTokenAddress: string,
        rewardsControllerAddress: string,
        poolAddressesProviderRegistryAddress: string,
        decimals: number,
        owner: string,
    ): Promise<AaveV3YieldPool> => {
        const AaveV3YieldPool = (await ethers.getContractFactory("AaveV3YieldPool")) as AaveV3YieldPool__factory;
        return await AaveV3YieldPool.deploy(
            aTokenAddress,
            rewardsControllerAddress,
            poolAddressesProviderRegistryAddress,
            'aUSDC yield',
            'aUSDCY',
            decimals,
            owner
        );
    };

    const supplyTokenTo = async (user: SignerWithAddress, amount: BigNumber) => {
        const userAddress = user.address;
        await usdcToken.mint(userAddress, amount);
        await usdcToken.connect(user).approve(aaveV3YieldPool.address, MaxUint256);
        await aaveV3YieldPool.connect(user).supplyTokenTo(amount, userAddress);
    };

    const sharesTokenTo = async (shares: BigNumber, yieldPoolTotalSupply: BigNumber) => {
        const totalShares = await aaveV3YieldPool.totalSupply();
        return shares.mul(yieldPoolTotalSupply).div(totalShares);
    };

    const tokenToShares = async (token: BigNumber, yieldPoolTotalSupply: BigNumber) => {
        const totalShares = await aaveV3YieldPool.totalSupply();
        return token.mul(totalShares).div(yieldPoolTotalSupply);
    };

    beforeEach(async () => {
        const { deployMockContract } = waffle;
        [contractsOwner, yieldPoolOwner, wallet2, attacker] = await getSigners();
        const ERC20MintableContract = await getContractFactory("ERC20Mintable", contractsOwner);
        erc20Token = await deployMockContract(contractsOwner, SafeERC20);
        usdcToken = (await ERC20Mintable.deploy('USDC Coin', 'USDC', DECIMALS)) as ERC20Mintable;
        const ATokenMintableContract = await getContractFactory('ATokenMintable', contractsOwner);

        aToken = (await ATokenMintable.deploy(
            usdcToken.address,
            'Aave interest bearing USDC',
            'aUSDC',
            DECIMALS,
        )) as ATokenMintable;

        const AavePoolContract = await getContractFactory('AavePool', contractsOwner);
        pool = (await AavePoolContract.deploy(usdcToken.address, aToken.address)) as AavePool;
        rewardsController = await deployMockContract(contractsOwner, IRewardsController);
        poolAddressesProvider = await deployMockContract(contractsOwner, IPoolAddressesProvider);
        poolAddressesProviderRegistry = await deployMockContract(contractsOwner, IPoolAddressesProviderRegistry);

        await poolAddressesProvider.mock.getPool.returns(pool.address);
        await poolAddressesProviderRegistry.mock.getAddressesProvidersList.returns([poolAddressesProvider.address]);

        if(!constructorTest) {
            aaveV3YieldPool = await deployAaveV3YieldPool(
                aToken.address,
                rewardsController.address,
                poolAddressesProviderRegistry.address,
                DECIMALS,
                yieldPoolOwner.address
            );
        }
    });

    describe('Construction of contracts', function () {
        beforeEach(() => {
            constructorTest = true;
        });

        afterEach(() => {
            constructorTest = false
        });

        it("Should deploy a new AaveV3YieldPool", async () => {
            const aaveV3YieldPool = await deployAaveV3YieldPool(
                aToken.address,
                rewardsController.address,
                poolAddressesProviderRegistry.address,
                DECIMALS,
                yieldPoolOwner.address
            );

            await expect(aaveV3YieldPool.deployTransaction)
                .to.emit(aaveV3YieldPool, 'AaveV3YieldPoolInitialized')
                .withArgs(
                    aToken.address,
                    rewardsController.address,
                    poolAddressesProviderRegistry.address,
                    'aUSDC yield',
                    'aUSDCY',
                    DECIMALS,
                    yieldPoolOwner.address
                );
        });
    })
});
