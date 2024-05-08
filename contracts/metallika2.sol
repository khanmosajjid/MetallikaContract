// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract Metallika2 is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    address public _owner;
    uint256 public minTransactionAmount; // Minimum transaction amount
    uint256 public maxTransactionAmount; // Maximum transaction amount
    // uint256 public transferDelay; // Transfer delay period

    uint256 public lockedLiquidityAmount; // Amount of liquidity tokens locked
    bool public liquidityLocked; // Flag to track if liquidity is locked

    bool public isDeflationary; // Deflationary state flag

    mapping(address => bool) public isExcludedFromTax;

    uint256 public burnableTax; // 0.5%

    uint256 public buySellTaxRate; // Rate at which gradually decreasing tax decreases
    uint256 public decreasingTaxInterval; // 1 hr
    uint256 public lastUpdatedTaxTimestamp; // Timestamp of the last tax update
    bool public isBuySellTaxEnabled;

    address public proposedOwner;
    address public proposedMintWallet;
    uint256 public proposedMintAmount;
    address[] public voters;
    mapping(address => bool) public hasVoted;
    mapping(address => bool) public hasVotedMint;
    mapping(address => bool) public hasVotedWithdrawFunds;

    //benificiary A,B,C

    struct Vesting {
        uint256 amount;
        address beneficiary;
        uint256 percentageOfTokensToBeReleased;
        uint256 timeInterval;
        uint256 lastWithdrawTimestamp;
        uint256 claimedTokens;
        bool isLocked;
    }

    mapping(address => bool) private isBlacklisted;
    mapping(address => uint256) private _transferAllowedAt;
    mapping(address => uint256) public _frozenWallets;
    mapping(address => bool) private _whitelistedWallets;
    mapping(address => bool) public signers;
    mapping(address => Vesting) public vestingInfo;

    address public router;

    event OwnershipTransferProposed(address indexed newOwner);
    event VoteCasted(address indexed voter, bool approve);

    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply,
        address _router,
        address[] memory _initialVoters
    ) public initializer {
        _owner = msg.sender;
        __ERC20_init(_name, _symbol);
        __ERC20Burnable_init();
        __Ownable_init();
        __Pausable_init();

        burnableTax = 50; // 0.5%

        isBuySellTaxEnabled = true;
        buySellTaxRate = 2000; // Rate at which gradually decreasing tax decreases
        decreasingTaxInterval = 300; // 5 min
        isDeflationary = true; // Deflationary state flag
        minTransactionAmount = 0; // Minimum transaction amount
        maxTransactionAmount = 100 ether;
        _mint(_owner, _initialSupply * (10 ** uint256(_decimals)));
        isBlacklisted[msg.sender] = false;
        _whitelistedWallets[msg.sender] = true;

        router = _router;
        isExcludedFromTax[address(this)] = true;
        isExcludedFromTax[router] = true;
        for (uint256 i = 0; i < _initialVoters.length; i++) {
            voters.push(_initialVoters[i]);
        }
    }

    // Modifier to check if liquidity is locked

    modifier onlyVoter() {
        require(isVoter(msg.sender), "Not a valid voter");
        _;
    }
    modifier onlyIfNotVoted() {
        require(!hasVoted[msg.sender], "Already voted");
        _;
    }
    modifier onlyIfNotMintVoted() {
        require(!hasVotedMint[msg.sender], "Already voted");
        _;
    }
     modifier onlyIfNotWithdrawVoted() {
        require(!hasVotedWithdrawFunds[msg.sender], "Already voted");
        _;
    }
    modifier liquidityNotLocked() {
        require(!liquidityLocked, "Liquidity is locked");
        _;
    }

    modifier whenNotFrozen(address wallet) {
        require(
            _frozenWallets[wallet] == 0 ||
                block.timestamp > _frozenWallets[wallet],
            "Wallet is frozen"
        );
        _;
    }

    modifier checkAmount(address wallet, uint256 amount) {
        if (!_whitelistedWallets[wallet]) {
            require(amount >= minTransactionAmount, "Amount below minimum");
            require(amount <= maxTransactionAmount, "Amount exceeds maximum");
        }
        _;
    }

    function isVoter(address _addr) internal view returns (bool) {
        for (uint256 i = 0; i < voters.length; i++) {
            if (voters[i] == _addr) {
                return true;
            }
        }
        return false;
    }

    function setIsExcludedFromTax(address wallet) external onlyOwner {
        isExcludedFromTax[wallet] = true;
    }

    function includeInTax(address wallet) external onlyOwner {
        isExcludedFromTax[wallet] = false;
    }

    function mint(address account, uint256 amount) internal onlyOwner {
        _mint(account, amount);
    }

    function blackList(address _user) external onlyOwner {
        require(!isBlacklisted[_user], "user already blacklisted");
        isBlacklisted[_user] = true;
    }

    function removeFromBlacklist(address _user) external onlyOwner {
        require(isBlacklisted[_user], "wallet is not  blacklisted");
        isBlacklisted[_user] = false;
    }

    function isBlackList(address _user) public view returns (bool) {
        return isBlacklisted[_user];
    }

    function setMinTransactionAmount(uint256 amount) external onlyOwner {
        minTransactionAmount = amount;
    }

    function setMaxTransferAmount(uint256 amount) external onlyOwner {
        maxTransactionAmount = amount;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function addToWhitelist(address wallet) external onlyOwner {
        _whitelistedWallets[wallet] = true;
    }

    function removeFromWhitelist(address wallet) external onlyOwner {
        _whitelistedWallets[wallet] = false;
    }

    // Enable or disable deflationary mechanism
    function setDeflationary(bool _enabled) external onlyOwner {
        isDeflationary = _enabled;
    }

    function disableBuySellTax(bool _enabled) external onlyOwner {
        isBuySellTaxEnabled = _enabled;
    }

    function setBurnableTax(uint256 _burnableTax) external onlyOwner {
        burnableTax = _burnableTax;
    }

    function isWhitelisted(address user) public view returns (bool) {
        return _whitelistedWallets[user];
    }

    function freezeWallet(
        address wallet,
        uint256 freezeDuration
    ) external onlyOwner {
        require(wallet != address(0), "Invalid wallet address");
        _frozenWallets[wallet] = block.timestamp + freezeDuration;
    }

    function unfreezeWallet(address wallet) external onlyOwner {
        _frozenWallets[wallet] = 0;
    }

    // Function to update the gradually decreasing tax rate

    function addVoter(address _voter) external onlyOwner {
        require(_voter != address(0), "Address in zero address");
        voters.push(_voter);
    }

    function removeVoter(address _voterAddress) external onlyOwner {
        // Find the index of the voter in the voters array
        uint256 voterIndex;
        bool found = false;
        for (uint256 i = 0; i < voters.length; i++) {
            if (voters[i] == _voterAddress) {
                voterIndex = i;
                found = true;
                break;
            }
        }

        // If the voter is found, remove them from the array
        if (found) {
            voters[voterIndex] = voters[voters.length - 1];
            voters.pop();
        }
    }

    function setBuySellTaxRate(uint256 _rate) external onlyOwner {
        buySellTaxRate = _rate;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override whenNotPaused whenNotFrozen(msg.sender) returns (bool) {
        require(!isBlacklisted[msg.sender], "Sender's wallet is blacklisted");
        require(!isBlacklisted[recipient], "Receiver's wallet is blacklisted");

        _transfer(msg.sender, recipient, amount); // Transfer without burning

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        override
        whenNotFrozen(from)
        checkAmount(msg.sender, amount)
        returns (bool)
    {
        require(!isBlacklisted[from], "Sender's wallet is blacklisted");
         require(!isBlacklisted[to], "Receiver's wallet is blacklisted");

        address spender = msg.sender;
        _spendAllowance(from, spender, amount);

        _transfer(from, to, amount);

        return true;
    }

    // Transfer function with auto liquidity and tax
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override checkAmount(sender, amount) {
        require(!isBlacklisted[sender], "Sender's wallet is blacklisted");
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 initialAmount = amount;

        if (isExcludedFromTax[sender] || isExcludedFromTax[recipient]) {
            super._transfer(msg.sender, recipient, amount);
            return;
        }
        if (isDeflationary) {
            uint256 burnAmount = ((initialAmount * burnableTax) / 10000); // Calculate the amount to burn
            _burn(sender, burnAmount); // Burn tokens
            amount = amount - burnAmount;
        }

        if (isBuySellTaxEnabled) {
            uint256 buySellTax = (buySellTaxRate * initialAmount) / 10000;
            super._transfer(sender, _owner, buySellTax);
            amount = amount - (buySellTaxRate * initialAmount) / 10000;
        }

        // Transfer the remaining amount
        super._transfer(sender, recipient, amount);
    }

    receive() external payable {}

    function burnFrom(
        address account,
        uint256 amount
    ) public virtual override onlyOwner {
        _burn(account, amount);
    }

    // Function to add vesting for a wallet
    function addVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 percentageToRelease,
        uint256 timeInterval
    ) external onlyOwner {
        require(
            beneficiary != address(0),
            "Beneficiary address cannot be zero"
        );
        require(
            percentageToRelease > 0 && percentageToRelease <= 10000,
            "Percentage must be between 1 and 100"
        );
        require(timeInterval > 0, "Time interval must be greater than zero");
        Vesting storage vesting = vestingInfo[beneficiary];
        vesting.amount = amount;
        vesting.beneficiary = beneficiary;
        vesting.percentageOfTokensToBeReleased = percentageToRelease;
        vesting.timeInterval = timeInterval;
        vesting.lastWithdrawTimestamp = block.timestamp;
        vesting.claimedTokens = 0;
        vesting.isLocked = false;
    }

    function claim() external {
        uint256 tokensToRelease;
        Vesting storage vesting = vestingInfo[msg.sender];
        uint256 totalVested = vesting.amount;
        require(vesting.amount > 0, "No vesting schedule found for the sender");

        if (vesting.isLocked == false) {
            uint256 currentTime = block.timestamp;
            tokensToRelease = totalVested - vesting.claimedTokens;
            vesting.claimedTokens += tokensToRelease;
            vesting.lastWithdrawTimestamp = currentTime;
        } else {
            uint256 currentTime = block.timestamp;
            uint256 elapsedTime = currentTime - vesting.lastWithdrawTimestamp;

            require(
                elapsedTime >= vesting.timeInterval,
                "Tokens cannot be claimed yet"
            );

            // Calculate the tokens to release in this claim
            tokensToRelease =
                (totalVested * vesting.percentageOfTokensToBeReleased) /
                10000;
            vesting.claimedTokens += tokensToRelease;
            vesting.lastWithdrawTimestamp = currentTime;

            // Transfer the tokens to the beneficiary
        }
        require(
            tokensToRelease <= totalVested,
            "Tokens to claim exceed total vested tokens"
        );
        require(
            vesting.claimedTokens <= vesting.amount,
            "Not enough tokens in the vesting schedule"
        );
        _transfer(_owner, msg.sender, tokensToRelease);
    }

    function unlockVesting(address beneficiary) external onlyOwner {
        require(beneficiary != address(0), "Invalid benificiary address");
        Vesting storage vesting = vestingInfo[msg.sender];
        vesting.isLocked = false;
    }

    function withdrawChainCoin(address payable _receiver) external onlyOwner {
        require(_receiver != address(0), "Invalid address");
        uint256 approvalCount = 0;
        uint256 totalVoters = voters.length;

        for (uint256 i = 0; i < totalVoters; i++) {
            if (hasVotedWithdrawFunds[voters[i]]) {
                approvalCount++;
            }
        }

        // Assuming that more than half of the voters should approve
        bool approve = (approvalCount == totalVoters);

        require(approve, "Insufficient approvals");

        _receiver.transfer(address(this).balance);
    }

    function withdrawToken(
        address receiver,
        IERC20 _token
    ) external onlyOwner {
        uint256 approvalCount = 0;
        uint256 totalVoters = voters.length;

        for (uint256 i = 0; i < totalVoters; i++) {
            if (hasVotedWithdrawFunds[voters[i]]) {
                approvalCount++;
            }
        }

        // Assuming that more than half of the voters should approve
        bool approve = (approvalCount == totalVoters);

        require(approve, "Insufficient approvals");
        _token.transfer(receiver, _token.balanceOf(address(this)));
    }

    function proposeOwnershipTransfer(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        proposedOwner = newOwner;
        emit OwnershipTransferProposed(newOwner);
    }

    function proposeMint(address account, uint256 amount) external onlyOwner {
        require(account != address(0), "Mint account cannot be zero address");
        proposedMintWallet = account;
        proposedMintAmount = amount;
    }

    function cancelOwnershipTransfer() external onlyOwner {
        proposedOwner = address(0);
        for (uint256 i = 0; i < voters.length; i++) {
            hasVoted[voters[i]] = false;
        }
    }

    function castVote(bool approve) external onlyVoter onlyIfNotVoted {
        hasVoted[msg.sender] = approve;
        emit VoteCasted(msg.sender, approve);
    }

    function castMintVote(bool approve) external onlyVoter onlyIfNotMintVoted {
        hasVotedMint[msg.sender] = approve;
        emit VoteCasted(msg.sender, approve);
    }
    function castWithdrawFundVote(bool approve) external onlyVoter onlyIfNotMintVoted {
        hasVotedWithdrawFunds[msg.sender] = approve;
        emit VoteCasted(msg.sender, approve);
    }

    function finalizeOwnershipTransfer() external onlyOwner {
        uint256 approvalCount = 0;
        uint256 totalVoters = voters.length;

        for (uint256 i = 0; i < totalVoters; i++) {
            if (hasVoted[voters[i]]) {
                approvalCount++;
            }
        }

        // Assuming that more than half of the voters should approve
        bool approve = (approvalCount == totalVoters);

        require(approve, "Insufficient approvals");

        address previousOwner = owner();
        address newOwner = proposedOwner;

        // Transfer ownership
        super.transferOwnership(newOwner);

        // Reset voting state
        proposedOwner = address(0);
        for (uint256 i = 0; i < totalVoters; i++) {
            hasVoted[voters[i]] = false;
        }

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function finalizeMint() external onlyOwner {
        uint256 approvalCount = 0;
        uint256 totalVoters = voters.length;

        for (uint256 i = 0; i < totalVoters; i++) {
            if (hasVotedMint[voters[i]]) {
                approvalCount++;
            }
        }

        // Assuming that more than half of the voters should approve
        bool approve = (approvalCount == totalVoters);

        require(approve, "Insufficient approvals");

        address previousOwner = owner();
        address newOwner = proposedOwner;

        // Transfer ownership
        mint(proposedMintWallet, proposedMintAmount);

        // Reset voting state
        proposedMintWallet = address(0);
        proposedMintAmount = 0;
        for (uint256 i = 0; i < totalVoters; i++) {
            hasVotedMint[voters[i]] = false;
        }
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        revert("Please Call Finalize Transfer Ownership");
    }
}
