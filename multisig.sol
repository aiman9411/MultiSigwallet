// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract MultiSigWallet {
    // @dev Check purpose of indexed
    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(address indexed owner, uint indexed txIndex, address indexed to, uint value, bytes data);
    event ConfirmTransaction(address indexed owner, uint txIndex);
    event RevokeConfirmation(address indexed owner, uint txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public numConfirmationRequired;

    struct Transaction{
        address sender;
        address to;
        uint value;
        // @dev Check purpose of data
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    mapping(uint => mapping(address => bool)) isConfirmed;

    Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier notSender(uint _txIndex) {
        require(transactions[_txIndex].sender != msg.sender, "Sender not allowed to confirm");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "Trx does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "Trx executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "Trx already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint _numConfirmationRequired) {
        uint minimumApproved = _owners.length / 2 + 1;
        require(_owners.length > 2, "Insufficient owners");
        require(_numConfirmationRequired >= minimumApproved && _numConfirmationRequired < _owners.length, "Invalid number of required tx");

        for(uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid address");
            require(!isOwner[owner], "Owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationRequired = _numConfirmationRequired; 
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        uint txIndex = transactions.length;
        transactions.push(
            Transaction({
                sender: msg.sender,
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint _txIndex) 
        public 
        onlyOwner 
        txExists(_txIndex)
        notSender(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex) {
            Transaction storage transaction = transactions[_txIndex];
            transaction.numConfirmations += 1;
            isConfirmed[_txIndex][msg.sender] = true;
            emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex) {
            Transaction storage transaction = transactions[_txIndex];
            require(transaction.numConfirmations >= numConfirmationRequired, "More confirmation required");
            transaction.executed = true;
            (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
            require(success, "tx failed");
            emit ExecuteTransaction(msg.sender, _txIndex);
        }

    function revokeTransaction(uint _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex) {
            Transaction storage transaction = transactions[_txIndex];
            require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");
            transaction.numConfirmations -= 1;
            isConfirmed[_txIndex][msg.sender] = false;
            emit RevokeConfirmation(msg.sender, _txIndex);
        }

    function getTransactionsCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _txIndex) public view 
    returns (
        address to,
        uint value,
        bytes memory data,
        bool executed,
        uint256 numConfirmations
    ) {
        Transaction storage transaction = transactions[_txIndex];
        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }

    function viewContractBalance() public view returns (uint256) {
        return address(this).balance;
    }


}
