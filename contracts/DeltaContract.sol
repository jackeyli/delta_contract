// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Owner
 * @dev Set & change owner
 */
contract DeltaContract {

    address private owner;
    enum RoundStatus {Started,Running,Aggregating,Finished}
    mapping(bytes32 => Task) createdTasks;
    mapping(bytes32 => TaskRound[]) taskRounds;
    mapping(bytes32 => RoundModelCommitments[]) roundModelCommitments;
    struct RoundModelCommitments{
        mapping(address=>CommitmentData) data;
    }
    struct Task {
        address creator;
        string dataSet;
        bytes32 commitment;
        uint64 currentRound;
    }
    struct Candidate {
        bytes32 pk1;
        bytes32 pk2;
    }
    struct TaskRound {
        uint64 currentRound;
        uint32 maxSample;
        uint32 minSample;
        RoundStatus status;
        mapping(address=>Candidate) candidates;
        uint256 roundStartBlockNum;
        uint256 calcStartBlockNum;
        uint32 joinTimeout;
        uint32 computTimeout;
    }
    
    struct ExtCallTaskRoundStruct {
        uint64 currentRound;
        uint32 maxSample;
        uint32 minSample;
        RoundStatus status;
        uint256 roundStartBlockNum;
        uint256 calcStartBlockNum;
        uint32 joinTimeout;
        uint32 computTimeout;
    }
    
    struct CommitmentData {
        bytes weightCommitment;
        bytes seedCmmtmnt;
        bytes secretKeyMaskCmmtmnt;
    }
    // event for EVM logging
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
    // triggered when task created 
    event TaskCreated(address indexed creator,bytes32 taskId,string dataSet,bytes32 taskCommitment);
    // triggered when task developer call startRound
    event RoundStart(bytes32 taskId,uint64 round);
    // triggered when task developer call selectCandidates
    event PartnerSelected(bytes32 taskId,uint64 round,address[] addrs);
    // triggered when task developer call startAggregate
    event AggregatingStarted(bytes32 taskId,uint64 round,address[] onlineClients);
    
    // modifier to check if caller is owner
    modifier isOwner() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(msg.sender == owner, "Caller is not owner");
        _;
    }
    
    modifier taskExists(bytes32 task_id) {
        require (createdTasks[task_id].creator != address(0), "Task not exists");
        _;
    }
    
    modifier roundExists(bytes32 task_id,uint64 round) {
        TaskRound[] storage rounds = taskRounds[task_id];
        require(rounds.length > 1 && rounds.length - 1== round,"this round has finished or it hasn't been started yet.");
        _;
    }
    
    modifier roundcmmtExists(bytes32 task_id,uint64 round) {
        RoundModelCommitments[] storage cmmts = roundModelCommitments[task_id];
        require(cmmts.length > round,"The Task Round Must exists");
        _;
    }
    
    modifier taskOwner(bytes32 task_id) {
        require(createdTasks[task_id].creator == msg.sender,"Must called by the task owner");
        _;
    }
    
    /**
     * @dev Set contract deployer as owner
     */
    constructor() {
        owner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        emit OwnerSet(address(0), owner);
    }
    
    /**
      * @dev get task info data
      * @param taskId taskId
      */
    function getTaskData(bytes32 taskId) taskExists(taskId) public view returns (Task memory task) {
        task = createdTasks[taskId];
    }
    
     /**
      * @dev called by task developer, notifying all clients that a new learning task has been published 
      * @param dataSet data set name (file/folder name of training data)
      * @param commitment training code hash (client validation purpose)
      * @return taskId taskId
      */
    function createTask(string calldata dataSet ,bytes32 commitment) payable public returns(bytes32 taskId){
         bytes32 task_id = keccak256(abi.encode(block.timestamp,msg.sender,dataSet,commitment));
         createdTasks[task_id] = Task({creator:msg.sender,dataSet:dataSet,commitment:commitment,currentRound:0});
         taskId = task_id;
         TaskRound[] storage rounds = taskRounds[taskId];
         rounds.push();
         emit TaskCreated(msg.sender,task_id,dataSet,commitment);
    }
    
     /**
      * @dev called by task developer, notifying all clients that a new computing round is started and open for joining
      * @param taskId taskId
      * @param round the round to start
      */
    function startRound(bytes32 taskId,uint64 round,uint32 maxSample,uint32 minSample,uint32 joinTimeout,uint32 computTimeout) taskExists(taskId) taskOwner(taskId) public {
        TaskRound[] storage rounds = taskRounds[taskId];
        require(rounds.length == round,"the round has been already started or the pre round does not exist");
        Task storage task = createdTasks[taskId];
        task.currentRound = round;
        rounds.push();
        rounds[round].currentRound = round;
        rounds[round].maxSample = maxSample;
        rounds[round].minSample = minSample;
        rounds[round].status = RoundStatus.Started;
        rounds[round].roundStartBlockNum = block.number;
        rounds[round].calcStartBlockNum = 0;
        rounds[round].joinTimeout = joinTimeout;
        rounds[round].computTimeout = computTimeout;
        RoundModelCommitments[] storage cmmts = roundModelCommitments[taskId];
        cmmts.push();
        emit RoundStart(taskId,round);
    }
    
    /**
      * @dev called by client, join for that round of computation
      * @param taskId taskId
      * @param round the round to join
      * @param pk1 used for secure communication channel establishment
      * @param pk2 used for mask generation
      */
    function joinRound(bytes32 taskId,uint64 round,bytes32 pk1,bytes32 pk2) taskExists(taskId) roundExists(taskId,round) public returns(bool){
        TaskRound[] storage rounds = taskRounds[taskId];
        TaskRound storage thisRound = rounds[rounds.length - 1];
        Task storage thisTask = createdTasks[taskId];
        require(thisRound.roundStartBlockNum + thisRound.joinTimeout >= block.number,"Join deadline has passed");
        require(thisRound.candidates[msg.sender].pk1 == 0x0,"Cannot join the same round multiple times");
        thisRound.candidates[msg.sender] = Candidate({pk1:pk1,pk2:pk2});
        return true;
    }
    
    function getCandidatePks(bytes32 taskId,uint64 round,address candidateAddr) roundExists(taskId,round) public view returns (Candidate memory candidate) {
        candidate = taskRounds[taskId][round].candidates[candidateAddr];
    }
    
    /**
      * @dev getting task round infos, this function is called for multiple purposes???one is for task developer to fetch registed clients after round start and another is for 
      * clients to get pks 
      * @param taskId taskId
      * @param round the round to fetch
      * @return taskround the task round infos
      */
    function getTaskRound(bytes32 taskId,uint64 round) roundExists(taskId,round) public view returns(ExtCallTaskRoundStruct memory taskround) {
        TaskRound storage temp = taskRounds[taskId][round];
        taskround = ExtCallTaskRoundStruct({currentRound:temp.currentRound,maxSample:temp.maxSample,minSample:temp.minSample,status:temp.status,roundStartBlockNum:temp.roundStartBlockNum,
            calcStartBlockNum:temp.calcStartBlockNum,
            joinTimeout:temp.joinTimeout,
            computTimeout:temp.computTimeout
        });
    }
    
     /**
      * @dev called by task developer, randomly choose candidates to be computation nodes
      * @param cltaddrs selected client addresses
      */
    function selectCandidates(bytes32 taskId,uint64 round,address[] calldata cltaddrs) taskOwner(taskId) roundExists(taskId,round) public {
        require(cltaddrs.length > 0,"Must provide addresses");
        TaskRound storage curRound = taskRounds[taskId][round];
        for(uint i = 0; i < cltaddrs.length; i ++) {
            require(curRound.candidates[cltaddrs[i]].pk1 != 0x00,"Candidate must exist");
        }
        curRound.calcStartBlockNum = block.number;
        curRound.status = RoundStatus.Running;
        emit PartnerSelected(taskId,round,cltaddrs);
    }
    
     /**
      * @dev called by task developer, get commitments from blockchain
      * @dev (Server has to call this method for every clients to get their commiments as the return value couldn't contain mapping type in solidity(damn it))
      * @param taskId taskId
      * @param clientaddress the client that publish the commitments  
      * @param round the round of that commitment
      * @return commitment commitment data
      */
    function getCommitment(bytes32 taskId,address clientaddress,uint64 round) roundExists(taskId,round) roundcmmtExists(taskId,round) public view returns(CommitmentData memory commitment) {
        RoundModelCommitments[] storage cmmts = roundModelCommitments[taskId];
        require(cmmts.length >= round,"The Task Round Must exists");
        RoundModelCommitments storage cmmt = cmmts[round];
        commitment = cmmt.data[clientaddress];
    }
    
    /**
     * @dev called by task developer, notifying all participants for aggregating
     * @param taskId taskId
     * @param round the task round
     */
    function startAggregate(bytes32 taskId,uint64 round,address[] calldata onlineClients) taskOwner(taskId) roundExists(taskId,round) public {
        TaskRound storage curRound = taskRounds[taskId][round];
        require(curRound.status == RoundStatus.Running,"This round is not running now");
        curRound.status = RoundStatus.Aggregating;
        for(uint i = 0; i < onlineClients.length; i ++) {
            require(curRound.candidates[onlineClients[i]].pk1 != 0x00,"Candidate must exist");
        }
        emit AggregatingStarted(taskId,round,onlineClients);
    }
    
    /**
     * @dev called by task developer, close round
     * @param taskId taskId
     * @param round the task round
     */
    function endRound(bytes32 taskId,uint64 round) taskOwner(taskId) roundExists(taskId,round) public {
        TaskRound storage curRound = taskRounds[taskId][round];
        curRound.status = RoundStatus.Finished;
    }
    
    /**
     * @dev called by client, upload weight commitment
     * @param taskId taskId
     * @param round the task round
     * @param weightCommitment masked model incremental commitment
     */
    function uploadWeightCommitment(bytes32 taskId,uint64 round,bytes calldata weightCommitment) roundExists(taskId,round) public {
        require(weightCommitment.length < 1024 * 1024 * 10);
        TaskRound storage curRound = taskRounds[taskId][round];
        require(curRound.status == RoundStatus.Running,"This round is not running now");
        require(curRound.calcStartBlockNum + curRound.computTimeout >= block.number,"upload deadline has passed");
        RoundModelCommitments storage commitments = roundModelCommitments[taskId][round];
        commitments.data[msg.sender].weightCommitment = weightCommitment;
    }
    /**
     * @dev called by client, upload secret sharing seed commitment
     * @param taskId taskId
     * @param round the task round
     * @param seedCmmtmnt secret sharing piece of seed mask
     */
    function uploadSeedCommitment(bytes32 taskId,uint64 round,bytes calldata seedCmmtmnt) roundExists(taskId,round) public {
        require(seedCmmtmnt.length <= 256);
        RoundModelCommitments storage cmmts = roundModelCommitments[taskId][round];
        cmmts.data[msg.sender].seedCmmtmnt = seedCmmtmnt;
    }
    
    /**
     * @dev called by client, upload secret sharing secret key mask commitment
     * @param taskId taskId
     * @param round the task round
     * @param secretKeyMaskCmmtmnt secret sharing piece of secret key mask
     */
    function uploadSkMaskCommitment(bytes32 taskId,uint64 round,bytes calldata secretKeyMaskCmmtmnt) roundExists(taskId,round) public {
        require(secretKeyMaskCmmtmnt.length <= 256);
        RoundModelCommitments storage cmmts = roundModelCommitments[taskId][round];
        cmmts.data[msg.sender].secretKeyMaskCmmtmnt = secretKeyMaskCmmtmnt;
    }
    
    
    /**
     * @dev Change owner
     * @param newOwner address of new owner
     */
    function changeOwner(address newOwner) public isOwner {
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Return owner address 
     * @return address of owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }
}