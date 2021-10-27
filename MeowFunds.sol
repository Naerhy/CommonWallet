// SPDX-License-Identifier: MIT

/*
	- get list of all WL addresses -> problem = public can get all DAO addresses

	- onlyValidId modifier on some public view functions - [ ? ]

*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MeowFunds is Ownable {

	struct S_Requests {
		uint id;
		address applicant;
		uint requestedAmount;
		string message;
		address[] approvals;
		bool approved;
	}

	S_Requests[] private allRequests;
	mapping(address => bool) private whitelist;
	uint private nbWhitelist;

	event SetWhitelistStatus(address userAddress, bool status);
	event DepositFunds(address userAddress, uint amount);
	event RequestWithdrawal(uint id, address applicant, uint requestedAmount, string message);
	event ApproveRequest(uint id, address userAddress);
	event WithdrawFunds(uint id, address to, uint amount);

	modifier onlyWhitelist() {
		require(getWhitelistStatus(_msgSender()) == true, "Address isn't whitelisted");
		_;
	}

	modifier onlyValidId(uint id) {
		require(id < allRequests.length && id >= 0, "Invalid request ID");
		_;
	}

	function setWhitelistStatus(address userAddress, bool status) public onlyOwner {
		require(getWhitelistStatus(userAddress) != status, "Unable to set the same status");
		whitelist[userAddress] = status;
		if (status == true)
			nbWhitelist++;
		else
			nbWhitelist--;
		emit SetWhitelistStatus(userAddress, status);
	}

	function getWhitelistStatus(address userAddress) public view returns (bool) {
		return whitelist[userAddress];
	}

	function getNbWhitelist() public view returns (uint) {
		return nbWhitelist;
	}

	function getContractBalance() private view returns (uint) {
		return address(this).balance;
	}

	function getRequestInfo(uint id) public view returns (uint, address, uint, string memory, address[] memory, bool) {
		return (allRequests[id].id, allRequests[id].applicant, allRequests[id].requestedAmount, allRequests[id].message, allRequests[id].approvals, allRequests[id].approved);
	}

	function getApprovalStatus(uint id) public view returns (bool) {
		if (allRequests[id].approvals.length > nbWhitelist / 2)
			return (true);
		return (false);
	}

	function depositFunds() payable public onlyWhitelist {
		require(msg.value > 0, "Unable to send 0 coin");
		emit DepositFunds(_msgSender(), msg.value);
	}

	function requestWithdrawal(uint requestedAmount, string memory message) public onlyWhitelist {
		S_Requests memory newRequest = S_Requests(allRequests.length, _msgSender(), requestedAmount, message, new address[](0), false);
		allRequests.push(newRequest);
		emit RequestWithdrawal(allRequests.length, _msgSender(), requestedAmount, message);
	}

	function approveRequest(uint id) public onlyWhitelist onlyValidId(id) {
		require(_msgSender() != allRequests[id].applicant, "Applicant can't approve his own request");
		require(checkAlreadyApproved(id, _msgSender()) == false, "This address has already approved");
		allRequests[id].approvals.push(_msgSender());
		emit ApproveRequest(id, _msgSender());
	}

	function withdrawFunds(uint id) public onlyWhitelist onlyValidId(id) {
		require(allRequests[id].applicant == _msgSender(), "Invalid address");
		require(getApprovalStatus(id) == true, "Not enough approvals");
		require(getContractBalance() >= allRequests[id].requestedAmount, "Contract balance is too low");
		payable(_msgSender()).transfer(allRequests[id].requestedAmount);
		allRequests[id].approved = true;
		emit WithdrawFunds(id, _msgSender(), allRequests[id].requestedAmount);
	}

	function checkAlreadyApproved(uint id, address userAddress) private view returns (bool) {
		for (uint i = 0; i < allRequests[id].approvals.length; i++) {
			if (allRequests[id].approvals[i] == userAddress)
				return true;
		}
		return false;
	}

}
