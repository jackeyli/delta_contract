// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "../../contracts/DeltaContract.sol";
contract Participant {
    DeltaContract theContract;
    constructor(DeltaContract ct) {
        theContract =  ct;
    }
    function createTask(string calldata dataSet ,bytes32 tskCmmtmnt) payable public returns(bytes32 taskId){
        taskId = theContract.createTask(dataSet,tskCmmtmnt);
    }
    function startRound(bytes32 taskId,uint64 round,uint32 maxSample,uint32 minSample,uint32 joinTimeout,uint32 computTimeout) public {
        theContract.startRound(taskId,round,maxSample,minSample,joinTimeout,computTimeout);
    }
    function joinRound(bytes32 taskId,uint64 round,bytes32 pk1,bytes32 pk2) public returns(bool){
        return theContract.joinRound(taskId,round,pk1,pk2);
    }
    function nop() public returns(bool){
        return true;
    }
    function selectCandidates(bytes32 taskId,uint64 round,address[] calldata cltaddrs) public {
        theContract.selectCandidates(taskId,round,cltaddrs);
    }
    function startAggregate(bytes32 taskId,uint64 round,address[] calldata onlineClients) public {
        theContract.startAggregate(taskId,round,onlineClients);
    }
    function uploadWeightCommitment(bytes32 taskId,uint64 round,bytes calldata weightCommitment) public {
        theContract.uploadWeightCommitment(taskId,round,weightCommitment);
    }
    function uploadSeedCommitment(bytes32 taskId,uint64 round,bytes calldata weightCommitment) public {
        theContract.uploadSeedCommitment(taskId,round,weightCommitment);
    }
    function uploadSkMaskCommitment(bytes32 taskId,uint64 round,bytes calldata weightCommitment) public {
        theContract.uploadSkMaskCommitment(taskId,round,weightCommitment);
    }
    function getCommitment(bytes32 taskId,address clientaddress,uint64 round) public view returns(DeltaContract.CommitmentData memory commitment) {
        commitment =  theContract.getCommitment(taskId,clientaddress,round);
    }
}
