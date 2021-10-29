// SPDX-License-Identifier: MIT

/*

- check all types of visibility for variables and functions 

- function to revoke approval

- set variable for requiredNb of Approvals -> setter + getter

- getter + setter for Request variables?

- restrictions on token to buy (ex: no ETH etc) ?

*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CommonWallet is Ownable {

	struct S_Requests {
		uint id;
		address applicant;
		address tokenToBuy;
		uint buyAmount;
		string message;
		address[] approvals;
		bool approved;
	}

	S_Requests[] private allRequests;
	address[] private whitelist;
	uint private nbWhitelist;

	mapping(address => uint) private wlBalances;

	event AddToWhitelist(address userAddress);
	event RemoveFromWhitelist(address userAddress);
	event DepositFunds(address userAddress, uint amount);
	event WithdrawFunds(address userAddress, uint amount);
	event RequestBuy(uint id, address applicant, address tokenToBuy, uint buyAmount, string message);
	event ApproveRequest(uint id, address userAddress);
	event FinalizeRequest(uint id);

	/////////////////////////////////////

	modifier onlyWhitelist() {
		require(isWhitelisted(_msgSender()) == true, "Address isn't whitelisted");
		_;
	}

	modifier onlyValidId(uint id) {
		require(id < allRequests.length && id >= 0, "Invalid request ID");
		_;
	}
	
	/////////////////////////////////////

	function getWhitelistedAddresses() public view returns (address[] memory) {
		return whitelist;
	}

	function getNbWhitelist() public view returns (uint) {
		return nbWhitelist;
	}

	function getAddrBalance(address userAddress) public view returns (uint) {
		return wlBalances[userAddress];
	}

	function getRequestInfo(uint id) public view returns (uint, address, address, uint, string memory, address[] memory, bool) {
		return (allRequests[id].id, allRequests[id].applicant, allRequests[id].tokenToBuy, allRequests[id].buyAmount, allRequests[id].message, allRequests[id].approvals, allRequests[id].approved);
	}

	// useless function? Better to use return values from getRequestInfo?
	function getApprovedStatus(uint id) private view returns (bool) {
		if (allRequests[id].approvals.length >= 2)
			return true;
		return false;
	}

	function getContractBalance() private view returns (uint) {
		return address(this).balance;
	}

	function setNbWhitelist(uint newNbWhitelist) private {
		nbWhitelist = newNbWhitelist;
	}

	function setAddrBalance(address userAddress, uint amount) private {
		wlBalances[userAddress] = amount;
	}

	/////////////////////////////////////

	function addToWhitelist(address userAddress) public onlyOwner {
		require(isWhitelisted(userAddress) == false, "Already whitelisted");
		whitelist.push(userAddress);
		setNbWhitelist(getNbWhitelist() + 1);
		emit AddToWhitelist(userAddress);
	}

	function removeFromWhitelist(address userAddress) public onlyOwner {
		require(isWhitelisted(userAddress) == true, "Not whitelisted");
		for (uint i = 0; i < getNbWhitelist(); i++) {
			if (whitelist[i] == userAddress)
				whitelist[i] = whitelist[getNbWhitelist() - 1];
		}
		whitelist.pop();
		setNbWhitelist(getNbWhitelist() - 1);
		emit RemoveFromWhitelist(userAddress);
	}

	function isWhitelisted(address userAddress) public view returns (bool) {
		for (uint i = 0; i < getNbWhitelist(); i++) {
			if (whitelist[i] == userAddress)
				return true;
		}
		return false;
	}

	/////////////////////////////////////

	function depositFunds() payable public onlyWhitelist {
		setAddrBalance(_msgSender(), getAddrBalance(_msgSender()) + msg.value);
		emit DepositFunds(_msgSender(), msg.value);
	}

	function withdrawFunds(uint amount) public onlyWhitelist {
		require(amount <= getAddrBalance(_msgSender()), "Balance too low");
		payable(_msgSender()).transfer(amount);
		setAddrBalance(_msgSender(), getAddrBalance(_msgSender()) - amount);
		emit WithdrawFunds(_msgSender(), amount);
	}

	/////////////////////////////////////

	function requestBuy(address tokenToBuy, uint buyAmount, string memory message) public onlyWhitelist {
		S_Requests memory newRequest = S_Requests(allRequests.length, _msgSender(), tokenToBuy, buyAmount, message, new address[](0), false);
		allRequests.push(newRequest);
		emit RequestBuy(allRequests.length, _msgSender(), tokenToBuy, buyAmount, message);
	}

	function approveRequest(uint id) public onlyWhitelist onlyValidId(id) {
		require(_msgSender() != allRequests[id].applicant, "Applicant can't approve his own request");
		require(checkAlreadyApproved(id, _msgSender()) == false, "This address has already approved");
		allRequests[id].approvals.push(_msgSender());
		emit ApproveRequest(id, _msgSender());
	}

	function checkAlreadyApproved(uint id, address userAddress) private view returns (bool) {
		for (uint i = 0; i < allRequests[id].approvals.length; i++) {
			if (allRequests[id].approvals[i] == userAddress)
				return true;
		}
		return false;
	}

	function finalizeRequestAndBuy(uint id) public onlyWhitelist onlyValidId(id) {
		require(getContractBalance() >= allRequests[id].buyAmount, "Contract balance is too low");
		require(getApprovedStatus(id) == true, "Not enough approvals");
		// transfer with router
		// transfer with router
		allRequests[id].approved = true;
		emit FinalizeRequest(id);
	}

}