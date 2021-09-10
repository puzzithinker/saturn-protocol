const {
    advanceBlock,
    advanceToBlock,
    increaseTime,
    increaseTimeTo,
    duration,
    revert,
    latestTime
  } = require('truffle-test-helpers');

const Spoon = artifacts.require('SpoonToken');
const BaseStrategy = artifacts.require('BaseStrategy');
const Vault = artifacts.require('Vault');
const FtmVault = artifacts.require('FtmVault');
const WFTM = artifacts.require('WFTM');
const RewardMinter = artifacts.require('RewardMinter');
const MasterChef = artifacts.require('MasterChef');

function toBN(x) {
    return '0x' + (Math.floor(x * (10 ** 18))).toString(16);
}

function toBN2(x) {
    return Math.floor(x * (10 ** 18));
}


contract('Update', ([alice, bob, carol, duck]) => {
    beforeEach(async () => {
        
        this.spoon = await Spoon.new('Spoon Token', 'SPOON', toBN(2000000), {from: alice});
        this.baseStrategy = await BaseStrategy.new(this.spoon.address, {from: alice});
        this.vault = await Vault.new(this.spoon.address, this.baseStrategy.address, 'ibSPOON', 'ibSPOON', {from: alice}); 
        this.wftm = await WFTM.new({from: alice});
        this.ftmStrategy = await BaseStrategy.new(this.wftm.address, {from: alice});
        this.ftmVault = await FtmVault.new(this.wftm.address, this.ftmStrategy.address, 'ibFTM', 'ibFTM', {from: alice})

    });


    /*it("ftm vault", async () => {
        await this.ftmVault.deposit(toBN(1), {from: alice, value: toBN(1)});
        console.log(await this.ftmVault.totalSupply());
        console.log(await this.ftmStrategy.totalBalance());
        await this.ftmVault.withdraw(toBN(1), {from: alice});
        console.log(await this.ftmVault.totalSupply());
    });*/

    /*it("reward minter", async () => {
        this.rewardMinter = await RewardMinter.new(this.spoon.address, {from: alice})
        await this.spoon.setMinter(this.rewardMinter.address, 100000);
        await this.rewardMinter.setMinter(alice, {from: alice});
        await this.rewardMinter.setLock(20, 90, {from: alice})
        await this.rewardMinter.setRelease(50, 1000, {from: alice});

        await this.rewardMinter.mint(bob, 1000, 10, 20);
        console.log(await this.spoon.balanceOf(bob));
        console.log(await this.rewardMinter.canClaim(bob))
        console.log(await this.rewardMinter.lockBalances(bob))
        console.log(await this.rewardMinter.claimAmounts(bob))

        await this.rewardMinter.claim(500, {from: bob})
        console.log(await this.rewardMinter.lockBalances(bob))
        console.log(await this.rewardMinter.claimAmounts(bob))

    })*/

    /*it("master chef", async () => {
        this.rewardMinter = await RewardMinter.new(this.spoon.address, {from: alice})
        await this.spoon.setMinter(this.rewardMinter.address, 1000000);

        this.master = await MasterChef.new(this.rewardMinter.address, {from: alice});
        //await this.master.setNextRewardRate(100, 100000, {from:alice});
        await this.rewardMinter.setMinter(this.master.address, {from: alice});

        await this.master.add(100, this.spoon.address, 0, false, {from: alice});
        await this.spoon.approve(this.master.address, 10000, {from: alice});
        await this.master.deposit(alice, 0, 100, {from: alice});
        await this.master.withdraw(alice, 0, 100, {from: alice});
        await this.master.updatePool(0);

    });*/
   

});
