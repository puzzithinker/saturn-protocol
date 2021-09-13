const {
    advanceBlock,
    advanceToBlock,
    increaseTime,
    increaseTimeTo,
    duration,
    revert,
    latestTime
  } = require('truffle-test-helpers');



function toBN(x) {
    return '0x' + (Math.floor(x * (10 ** 18))).toString(16);
}

function toBN2(x) {
    return Math.floor(x * (10 ** 18));
}


contract('Update', ([alice, bob, carol, duck]) => {
    beforeEach(async () => {
        
        

    });


    

});
