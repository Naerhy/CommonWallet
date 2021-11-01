// SPDX-License-Identifier: None

/*

- check all types of visibility for variables and functions 

- function to revoke approval -> me no comprendo ????

- restrictions on token to buy (ex: no ETH etc) ?

- need to multiply approve * WL addresses

- use WETH/WBNB/WFTM instead of stablecoin? Lower gas? Ask community

- setter/getter slippage ?

- getter nb de requests

- getter for specific request ?

*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

contract CommonWallet is Ownable {

	struct S_Requests {
		uint id;
		address applicant;
		address tokenToBuy;
		uint buyAmount;
		string routerName;
		string message;
		address[] approvals;
		bool approved;
	}

	S_Requests[] private allRequests;
	uint private nbRequests;

	address[] private whitelist;
	uint private nbWhitelist;

	uint private requiredNbApprovals;

	mapping(address => uint) private balances;

	IERC20 private depositToken;

	mapping(string => IUniswapV2Router02) private routers;
	string[] private routersNames;

	event AddToWhitelist(address userAddress);
	event RemoveFromWhitelist(address userAddress);
	event DepositFunds(address userAddress, uint amount);
	event WithdrawFunds(address userAddress, uint amount);
	event EmergencyWithdrawFunds();
	event BuyRequest(uint id, address applicant, address tokenToBuy, uint buyAmount, string message);
	event ApproveRequest(uint id, address userAddress);
	event FinalizeRequest(uint id);

	/////////////////////////////////////

	modifier onlyWhitelist() {
		require(isWhitelisted(_msgSender()) != -1, "Address isn't whitelisted.");
		_;
	}

	modifier onlyValidId(uint id) {
		require(id < getNbRequests() && id >= 0, "Invalid request ID.");
		_;
	}

	/////////////////////////////////////

	constructor(address depositTokenAddress) {
		depositToken = IERC20(depositTokenAddress);
		setRequiredNbApprovals(2);
	}

	/////////////////////////////////////

	function getRequestInfo(uint id) public view returns (S_Requests memory) {
		return allRequests[id];
	}

	function getNbRequests() public view returns (uint) {
		return nbRequests;
	}

	function getWhitelistAddress(uint i) private view returns (address) {
		return whitelist[i];
	}

	function getWhitelistAddresses() public view returns (address[] memory) {
		return whitelist;
	}

	function getNbWhitelist() private view returns (uint) {
		return nbWhitelist;
	}

	function getRequiredNbApprovals() public view returns (uint) {
		return requiredNbApprovals;
	}

	function getAddressBalance(address userAddress) public view returns (uint) {
		return balances[userAddress];
	}

	function getRouter(string memory routerName) private view returns (IUniswapV2Router02) {
		return routers[routerName];
	}

	function getRoutersNames() public view returns (string[] memory) {
		return routersNames;
	}

	// useless function? Better to use return values from getRequestInfo?
	function getApprovedStatus(uint id) private view returns (bool) {
		if (allRequests[id].approvals.length >= getRequiredNbApprovals())
			return true;
		return false;
	}

	/////////////////////////////////////

	function setNbRequests(uint newNbRequests) private {
		nbRequests = newNbRequests;
	} 

	// useless -> only used once
	function setWhitelistAddress(uint i, address userAddress) private {
		whitelist[i] = userAddress;
	}

	function setNbWhitelist(uint newNbWhitelist) private {
		nbWhitelist = newNbWhitelist;
	}

	function setRequiredNbApprovals(uint _requiredNbApprovals) public onlyOwner {
		requiredNbApprovals = _requiredNbApprovals;
	}

	function setAddressBalance(address userAddress, uint newBalance) private {
		balances[userAddress] = newBalance;
	}

	function setRouter(string memory routerName, address routerAddress) public onlyOwner {
		require(address(getRouter(routerName)) == address(0), "Router already exists.");
		routers[routerName] = IUniswapV2Router02(routerAddress);
		routersNames.push(routerName);
	}

	/////////////////////////////////////

	function addToWhitelist(address userAddress) public onlyOwner {
		require(isWhitelisted(userAddress) == -1, "Already whitelisted.");
		whitelist.push(userAddress);
		setNbWhitelist(getNbWhitelist() + 1);
		emit AddToWhitelist(userAddress);
	}

	function removeFromWhitelist(address userAddress) public onlyOwner {
		int index = isWhitelisted(userAddress);
		if (index != -1) {
			withdrawFundsRemovedFromWl(userAddress, getAddressBalance(userAddress));
			setWhitelistAddress(uint(index), getWhitelistAddress(getNbWhitelist() - 1));
			whitelist.pop();
			setNbWhitelist(getNbWhitelist() - 1);
			emit RemoveFromWhitelist(userAddress);
		}
	}

	function isWhitelisted(address userAddress) private view returns (int) {
		for (uint i = 0; i < getNbWhitelist(); i++) {
			if (getWhitelistAddress(i) == userAddress)
				return int(i);
		}
		return -1;
	}

	/////////////////////////////////////

	// user has to manually approve the depositToken before calling this!!
	function depositFunds(uint amount) public onlyWhitelist {
		depositToken.transferFrom(_msgSender(), address(this), amount);
		setAddressBalance(_msgSender(), getAddressBalance(_msgSender()) + amount);
		emit DepositFunds(_msgSender(), amount);
	}

	function withdrawFunds(uint amount) public onlyWhitelist {
		require(amount <= getAddressBalance(_msgSender()), "Can't withdraw more than your balance.");
		depositToken.transfer(_msgSender(), amount);
		setAddressBalance(_msgSender(), getAddressBalance(_msgSender()) - amount);
		emit WithdrawFunds(_msgSender(), amount);
	}

	function withdrawFundsRemovedFromWl(address userAddress, uint amount) private {
		depositToken.transfer(userAddress, amount);
		setAddressBalance(userAddress, getAddressBalance(userAddress) - amount);
	}

	function emergencyWithdrawFunds() public onlyOwner {
		// more security + protection ??
		depositToken.transfer(_msgSender(), depositToken.balanceOf(address(this)));
		emit EmergencyWithdrawFunds();
	}

	/////////////////////////////////////

	function buyRequest(address tokenToBuy, uint buyAmount, string memory routerName, string memory message) public onlyWhitelist {
		require(address(getRouter(routerName)) != address(0), "Router has not been added.");
		S_Requests memory newRequest = S_Requests(getNbRequests(), _msgSender(), tokenToBuy, buyAmount, routerName, message, new address[](0), false);
		allRequests.push(newRequest);
		setNbRequests(getNbRequests() + 1);
		emit BuyRequest(getNbRequests() - 1, _msgSender(), tokenToBuy, buyAmount, message);
	}

	function approveRequest(uint id) public onlyWhitelist onlyValidId(id) {
		require(_msgSender() != allRequests[id].applicant, "Applicant can't approve his own request.");
		require(checkAlreadyApproved(id, _msgSender()) == false, "This address has already approved.");
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
		require(getApprovedStatus(id) == true, "Not enough approvals.");
		swapRouter(allRequests[id].buyAmount, allRequests[id].tokenToBuy, allRequests[id].routerName);
		allRequests[id].approved = true;
		emit FinalizeRequest(id);
	}

	// check with invalid address not being a router
	function swapRouter(uint buyAmount, address tokenToBuy, string memory routerName) private {
		// check that tokenToBuy is correct and can be buyable on router
		// in order to reduce gas fees for next trades => approving max amount ?
		// still has to approve this at every call => create function to call it once (in addRouter ?)?
		// use a simple approve, not a require??
		require(depositToken.approve(address(getRouter(routerName)), 2**256 - 1) == true, "Approve failed.");
		address[] memory path = new address[](2);
		path[0] = address(depositToken);
		path[1] = tokenToBuy;
		uint minReceivedTokens = getRouter(routerName).getAmountsOut(buyAmount, path)[1];
		for (uint i = 0; i < getNbWhitelist(); i++)
		{
			if (getAddressBalance(getWhitelistAddress(i)) >= buyAmount) {
				getRouter(routerName).swapExactTokensForTokensSupportingFeeOnTransferTokens(buyAmount, minReceivedTokens / 100 * 85, path, getWhitelistAddress(i), block.timestamp + 300);
				setAddressBalance(getWhitelistAddress(i), getAddressBalance(getWhitelistAddress(i)) - buyAmount);
			}
		}
	}

}
