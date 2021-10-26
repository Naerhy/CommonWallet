// SPDX-License-Identifier: MIT

/*

	rajouter CD + limite withdrawfunds

	getter / setter for nbWhitelisted ??

*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MeowFunds is Ownable { // changer nom contrat

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

	/*
	event DepositFunds(address userAddress, uint256 amount);
	event RequestWithdrawal(uint16 id, address applicant, uint256 requestedAmount, string message);
	event ApproveRequest(uint16 id, address userAddress);
	event WithdrawFunds(uint16 id, address to, uint256 amount);
	*/

	modifier onlyWhitelisted() {
		require(getWhitelistStatus(_msgSender) == true, "Address isn't whitelisted");
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

	function depositFunds() payable public onlyWhitelisted {
		require(msg.value > 0, "Unable to send 0 coin");
		// emit DepositFunds(_msgSender, msg.value);
	}

	function requestWithdrawal(uint256 requestedAmount, string message) public onlyWhitelisted {
		S_Requests memory newRequest = S_Requests(allRequests.length, _msgSender, requestedAmount, message, new address[](0), false);
		allRequests.push(newRequest);
		// emit RequestWithdrawal(allRequests.length, _msgSender, requestedAmount, message);
	}

	function approveRequest(uint16 id) public onlyWhitelisted {
		require(id < allRequests.length, "Invalid ID"); // et id >= 0 ??
		require(_msgSender != allRequests[id].applicant, "Applicant can't approve his own request");
		require(hasAlreadyApproved(id, _msgSender) == false, "This address has already approved");
		allRequests[id].approved.push(_msgSender);
		// emit ApproveRequest(id, _msgSender);
	}

	function hasAlreadyApproved(uint16 id, address userAddress) private returns (bool) {
		for (int i = 0; i < allRequests[id].approved.length; i++) {
			if (allRequests[id].approved[i] == userAddress)
				return true;
		}
		return false;
	}

	function withdrawFunds(uint16 id) public onlyWhitelisted {
		require(id < allRequests.length, "Invalid ID"); // et id >= 0 ??
		require(allRequests[id].applicant == _msgSender, "Invalid address");
		require(allRequests[id].approved.length > nbWhitelisted / 2, "Not enough approvals");
		require(getContractBalance() >= allRequests[id].requestedAmount, "Contract balance is too low");
		payable(_msgSender()).transfer(allRequests[id].requestedAmount);
		allRequests[id].approved = true;
		// emit WithdrawFunds(id, _msgSender, allRequests[id].requestedAmount);
	}

	/*
	function getRequest(uint16 id) public view returns (uint16, address, uint256, string, address[], bool) {
		require(id < allRequests.length, "Invalid ID"); // et id >= 0 ??
		return (allRequests[id].id, allRequests[id].applicant, allRequests[id].requestedAmount, allRequests[id].message, allRequests[id].approvals, allRequests[id].approved);
	}
	*/

	function getContractBalance() private view returns (uint256) {
		return address(this).balance;
	}
}