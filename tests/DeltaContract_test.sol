// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "remix_tests.sol"; // this import is automatically injected by Remix.
import "./lib/Test_Participant.sol";
import "../contracts/DeltaContract.sol";

contract DeltaContractTest {
   
    DeltaContract dContract;
    Participant taskDeveloper;
    Participant clientA;
    Participant clientB;
    Participant clientC;
    bytes32 timeoutTaskId;
    bytes32 weightCommitmentTaskId;
    function beforeAll () public {
        dContract = new DeltaContract();
        taskDeveloper = new Participant(dContract);
        clientA = new Participant(dContract);
        clientB = new Participant(dContract);
        clientC = new Participant(dContract);
    }
    function CreateTaskShouldBeSuccessful () public {
        bytes32 t_id = taskDeveloper.createTask("myDataSet",0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e00);
        DeltaContract.Task memory taskData = dContract.getTaskData(t_id);
        Assert.equal(taskData.dataSet,"myDataSet", "CreateTaskFailed");
        Assert.equal(taskData.commitment,0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e00, "CreateTaskFailed");
        Assert.equal(taskData.currentRound,0, "CreateTaskFailed");
    }
    
    function StartRoundTests () public {
        bytes32 t_id = taskDeveloper.createTask("myDataSet",0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e01);
        try taskDeveloper.startRound(0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e00,0,3000,300,32,32)
         {
            Assert.ok(false,"should throw exception");
         } catch Error (string memory error) {
            Assert.equal(error,"Task not exists","StartRoundBatches failed");
        }
        try clientA.startRound(t_id,1,3000,300,32,32)
         {
            Assert.ok(false,"should throw exception");
         } catch Error (string memory error) {
            Assert.equal(error,"Must called by the task owner","StartRoundBatches failed");
        }
        try taskDeveloper.startRound(t_id,0,3000,300,32,32)
         {
            Assert.ok(false,"should throw exception");
         } catch Error (string memory error) {
            Assert.equal(error,"the round has been already started or the pre round does not exist","StartRoundBatches failed");
        }
        taskDeveloper.startRound(t_id,1,3000,300,32,32);
        DeltaContract.ExtCallTaskRoundStruct memory tRound = dContract.getTaskRound(t_id,1);
        Assert.equal(tRound.currentRound,1,"StartRoundBatches failed");
        Assert.equal(tRound.maxSample,3000,"StartRoundBatches failed");
        Assert.equal(tRound.minSample,300,"StartRoundBatches failed");
        Assert.equal(tRound.roundStartBlockNum,block.number,"StartRoundBatches failed");
        Assert.equal(tRound.calcStartBlockNum,0,"StartRoundBatches failed");
        Assert.equal(tRound.joinTimeout,32,"StartRoundBatches failed");
        Assert.equal(tRound.computTimeout,32,"StartRoundBatches failed");
    }
    function joinRoundTests() public {
        bytes32 t_id = taskDeveloper.createTask("myDataSet",0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e02);
        taskDeveloper.startRound(t_id,1,3000,300,32,32);
        try clientA.joinRound(0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e00,1,
                              0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e00,
                              0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e02)
        {
            Assert.ok(false,"should throw exception");
        } catch Error (string memory error) {
            Assert.equal(error,"Task not exists","joinRoundTests failed");
        }
        try clientA.joinRound(t_id,0,
                              0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e00,
                              0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e02)
        {
            Assert.ok(false,"should throw exception");
        } catch Error (string memory error) {
            Assert.equal(error,"this round has finished or it hasn't been started yet.","joinRoundTests failed");
        }
        clientA.joinRound(t_id,1,0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e00,0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e02);
        try clientA.joinRound(t_id,1,0xe83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e00,0xe83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e02) {
            Assert.ok(false,"should throw exception");
        } catch Error (string memory error) {
            Assert.equal(error,"Cannot join the same round multiple times","joinRoundTests failed");
        }
    }
    function createTaskJoinRoundTimeout() public {
         timeoutTaskId = taskDeveloper.createTask("myDataSet",0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e03);
         taskDeveloper.startRound(timeoutTaskId,1,3000,300,1,1);
    }
    function waitForABlock() public {
    }
    function checkTaskJoinRoundTimeout() public {
         clientA.nop();
         try  clientA.joinRound(timeoutTaskId,1,0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e03,0xd83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e04)
         {
             Assert.ok(false,"should throw exception");
         } catch Error (string memory error) {
            Assert.equal(error,"Join deadline has passed","joinRoundTests failed");
         }
    }
    function selectCandidatesTests() public {
        bytes32 t_id = taskDeveloper.createTask("myDataSet",0xa83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e02);
        taskDeveloper.startRound(t_id,1,3000,300,32,32);
        clientA.joinRound(t_id,1,0xe83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e01,0xe83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e02);
        clientB.joinRound(t_id,1,0xf83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e08,0xf83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e09);
        address[] memory lst = new address[](2);
        lst[0] = address(clientA);
        lst[1] = address(clientB);
        try clientA.selectCandidates(t_id,1,lst) {
            Assert.ok(false,"should throw exception");
        } catch Error (string memory error) {
            Assert.equal(error,"Must called by the task owner","selectCandidatesTest failed");
        }
        lst = new address[](2);
        lst[0] = address(clientA);
        lst[1] = address(clientC);
        try taskDeveloper.selectCandidates(t_id,1,lst) {
            Assert.ok(false,"should throw exception");
        } catch Error (string memory error) {
            Assert.equal(error,"Candidate must exist","selectCandidatesTest failed");
        }
        lst = new address[](2);
        lst[0] = address(clientA);
        lst[1] = address(clientB);
        taskDeveloper.selectCandidates(t_id,1,lst);
    }
    
    function startAggregateTests() public {
        bytes32 t_id = taskDeveloper.createTask("myDataSet",0xa83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e09);
        taskDeveloper.startRound(t_id,1,3000,300,32,32);
        clientA.joinRound(t_id,1,0xe83da96c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e01,0xe83da96c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e02);
        address[] memory lst = new address[](1);
        lst[0] = address(clientA);
        try taskDeveloper.startAggregate(t_id,1,lst) {
            Assert.ok(false,"should throw exception");
        } catch Error(string memory error) {
            Assert.equal(error,"This round is not running now","selectCandidatesTest failed");
        }
        taskDeveloper.selectCandidates(t_id,1,lst);
        lst[0] = address(clientB);
        try taskDeveloper.startAggregate(t_id,1,lst) {
            Assert.ok(false,"should throw exception");
        } catch Error(string memory error) {
            Assert.equal(error,"Candidate must exist","selectCandidatesTest failed");
        }
        lst[0] = address(clientA);
        taskDeveloper.startAggregate(t_id,1,lst);
    }
    function uploadWeightCommitmentTests() public {
        weightCommitmentTaskId = taskDeveloper.createTask("myDataSet",0xa83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e09);
        taskDeveloper.startRound(weightCommitmentTaskId,1,3000,300,32,1);
        clientA.joinRound(weightCommitmentTaskId,1,0xe83da96c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e01,0xe83da96c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e02);
        address[] memory lst = new address[](1);
        lst[0] = address(clientA);
        taskDeveloper.selectCandidates(weightCommitmentTaskId,1,lst);
    }
    function waitForABlockToCommitment() public {
    }
    function uploadWeightCommitmentShouldTimeout() public {
        bytes memory theBytes = new bytes(1);
        theBytes[0] = 0x01;
        try clientA.uploadWeightCommitment(weightCommitmentTaskId,1,theBytes) {
            Assert.ok(false,"should throw exception");
        } catch Error(string memory error) {
            Assert.equal(error,"upload deadline has passed","uploadWeightCommitmentShouldTimeout failed");
        }
    }
    
    function uploadWeightCommitmentShouldSuccess() public {
        bytes32 t_id = taskDeveloper.createTask("myDataSet",0xa83da95c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e09);
        taskDeveloper.startRound(t_id,1,3000,300,32,1);
        clientA.joinRound(t_id,1,0xe83da96c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e01,0xe83da96c058c118d61c20dba7a15f44fa0a4c079eff4ca94932f2baf31135e02);
        address[] memory lst = new address[](1);
        lst[0] = address(clientA);
        taskDeveloper.selectCandidates(t_id,1,lst);
        // bytes memory theBytes = new bytes(1);
        // theBytes[0] = 0x01;
        // clientA.uploadWeightCommitment(weightCommitmentTaskId,1,theBytes);
        // DeltaContract.CommitmentData memory cmmt =  taskDeveloper.getCommitment(t_id,address(clientA),1);
        // Assert.equal(cmmt.weightCommitment.length,1,"uploadWeightCommitmentShouldSuccess Failed");
    }
}
