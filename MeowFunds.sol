// SPDX-License-Identifier: MIT

/*
	- getter / setter for nbWhitelisted - [ ? ]

	- add another condition for validID -> has to be >= 0 - [ ? ]

*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MeowFunds is Ownable {

	struct S_Requests {
		uint16 id;
		address applicant;
		uint256 requestedAmount;
		string message;
		address[] approvals;
		bool approved;
	}

	S_Requests[] private allRequests;
	mapping(address => bool) private whitelistStatus;
	uint8 private nbWhitelisted;
	
	event DepositFunds(address userAddress, uint256 amount);
	event RequestWithdrawal(uint16 id, address applicant, uint256 requestedAmount, string message);
	event ApproveRequest(uint16 id, address userAddress);
	event WithdrawFunds(uint16 id, address to, uint256 amount);

	modifier onlyWhitelisted() {
		require(getWhitelistStatus(_msgSender()) == true, "Address isn't whitelisted");
		_;
	}

	modifier onlyValidId(uint16 id) {
		require(id < allRequests.length && id >= 0, "Invalid ID");
		_;
	}

	function setWhitelistStatus(address userAddress, bool status) public onlyOwner {
		require(getWhitelistStatus(userAddress) != status, "Unable to set the same status");
		whitelistStatus[userAddress] = status;
		if (status == true)
			nbWhitelisted++;
		else
			nbWhitelisted--;
	}

	function getWhitelistStatus(address userAddress) public view returns (bool) {
		return whitelistStatus[userAddress];
	}

	function getContractBalance() private view returns (uint256) {
		return address(this).balance;
	}

	function getRequestInformation(uint16 id) public view onlyWhitelisted onlyValidId(id) returns (uint16, address, uint256, string memory , address[] memory, bool) {
		return (allRequests[id].id, allRequests[id].applicant, allRequests[id].requestedAmount, allRequests[id].message, allRequests[id].approvals, allRequests[id].approved);
	}

	function getApprovalStatus(uint16 id) public view onlyWhitelisted returns (bool) {
		if (allRequests[id].approvals.length > nbWhitelisted / 2)
			return (true);
		return (false);
	}

	function depositFunds() payable public onlyWhitelisted {
		require(msg.value > 0, "Unable to send 0 coin");
		emit DepositFunds(_msgSender(), msg.value);
	}

	function requestWithdrawal(uint256 requestedAmount, string memory message) public onlyWhitelisted {
		S_Requests memory newRequest = S_Requests(uint16(allRequests.length), _msgSender(), requestedAmount, message, new address[](0), false);
		allRequests.push(newRequest);
		emit RequestWithdrawal(uint16(allRequests.length), _msgSender(), requestedAmount, message);
	}

	function approveRequest(uint16 id) public onlyWhitelisted onlyValidId(id) {
		require(_msgSender() != allRequests[id].applicant, "Applicant can't approve his own request");
		require(checkAlreadyApproved(id, _msgSender()) == false, "This address has already approved");
		allRequests[id].approvals.push(_msgSender());
		emit ApproveRequest(id, _msgSender());
	}

	function withdrawFunds(uint16 id) public onlyWhitelisted onlyValidId(id) {
		require(allRequests[id].applicant == _msgSender(), "Invalid address");
		require(getApprovalStatus(id) == true, "Not enough approvals");
		require(getContractBalance() >= allRequests[id].requestedAmount, "Contract balance is too low");
		payable(_msgSender()).transfer(allRequests[id].requestedAmount);
		allRequests[id].approved = true;
		emit WithdrawFunds(id, _msgSender(), allRequests[id].requestedAmount);
	}

	function checkAlreadyApproved(uint16 id, address userAddress) private view returns (bool) {
		for (uint256 i = 0; i < allRequests[id].approvals.length; i++) {
			if (allRequests[id].approvals[i] == userAddress)
				return true;
		}
		return false;
	}
}
