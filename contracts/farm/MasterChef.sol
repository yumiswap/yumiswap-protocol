// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

import '../libraries/SafeMath.sol';
import '../interfaces/IERC20.sol';
import '../token/SafeERC20.sol';
import '../libraries/Ownable.sol';
import "../token/YumiToken.sol";
import "./SyrupBar.sol";

// MasterChef is the master of YUMI. He can make YUMI and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once YUMI is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of YUMIs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCakePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accCakePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. CAKEs to distribute per block.
        uint256 lastRewardTime; // Last block time that CAKEs distribution occurs.
        uint256 accCakePerShare; // Accumulated CAKEs per share, times 1e12. See below.
    }

    // The YUMI TOKEN!
    YumiToken public cake;
    // The SYRUP TOKEN!
    SyrupBar public syrup;
    // Ecosystem funds address.
    address public devaddr;
    // Reserve address.
    address public reserveaddr;
    // SwapMining address
    address public miningaddr;


    // YUMI tokens created per second.
    uint256 public cakePerSecond;

    // set a max cake per second, which can never be higher than 1 per second
    uint256 public constant maxCakePerSecond = 1e18;

    // Bonus muliplier for early yumi makers.
    uint256 public BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block time when YUMI mining starts.
    uint256 public startTime;

    // The YUMI token max total supply 18,921,600
    uint256 public constant yumiMaxSupply = 18921600e18;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        YumiToken _cake,
        SyrupBar _syrup,
        address _devaddr,
        address _reserveaddr,
        address _miningaddr,
        uint256 _cakePerSecond,
        uint256 _startTime
    ) public {
        cake = _cake;
        syrup = _syrup;
        devaddr = _devaddr;
        reserveaddr = _reserveaddr;
        miningaddr = _miningaddr;
        cakePerSecond = _cakePerSecond;
        startTime = _startTime;
        totalAllocPoint = 0;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    mapping(IERC20 => bool) public poolExistence;
    modifier nonDuplicatedLP(IERC20 _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: Duplicated LPToken");
        _;
    }
    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner nonDuplicatedLP(_lpToken){
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTime =
            block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolExistence[_lpToken] = true;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardTime: lastRewardTime,
                accCakePerShare: 0
            })
        );
    }

    // Update the given pool's YUMI allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (cake.totalSupply() >= yumiMaxSupply) {
            return 0;
        }

        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending YUMIs on frontend.
    function pendingCake(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCakePerShare = pool.accCakePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardTime, block.timestamp);
            uint256 cakeReward =
                multiplier.mul(cakePerSecond).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accCakePerShare = accCakePerShare.add(
                cakeReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accCakePerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
        uint256 cakeReward =
            multiplier.mul(cakePerSecond).mul(pool.allocPoint).div(
                totalAllocPoint
            );

        // YumiSwap Tokenomics
        // total supply 18921600
        // 10% team
        // xYUMI reward 20%
        // LP farming 60%
        // NFT staking reward 3%
        // Trade mining 2%
        // Ecosystem(Preminted) 5%

        cake.mintFor(devaddr, cakeReward.mul(10).div(100));
        cake.mintFor(reserveaddr, cakeReward.mul(3).div(100));
        cake.mintFor(miningaddr, cakeReward.mul(2).div(100));

        cake.mintFor(address(syrup), cakeReward.mul(80).div(100));
        pool.accCakePerShare = pool.accCakePerShare.add(
            cakeReward.mul(80).mul(1e12).div(100).div(lpSupply)
        );
        pool.lastRewardTime = block.timestamp;
    }

    // Deposit LP tokens to MasterChef for YUMI allocation.
    function deposit(uint256 _pid, uint256 _amount) public {

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending =
                user.amount.mul(pool.accCakePerShare).div(1e12).sub(
                    user.rewardDebt
                );
            if (pending > 0) {
                safeCakeTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending =
            user.amount.mul(pool.accCakePerShare).div(1e12).sub(
                user.rewardDebt
            );
        if (pending > 0) {
            safeCakeTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe yumi transfer function, just in case if rounding error causes pool to not have enough YUMIs.
    function safeCakeTransfer(address _to, uint256 _amount) internal {
        syrup.safeCakeTransfer(_to, _amount);
    }

    // Changes cake token reward per second, with a cap of max cake per second
    // Good practice to update pools without messing up the contract
    function setCakePerSecond(uint256 _cakePerSecond) external onlyOwner {
        require(_cakePerSecond <= maxCakePerSecond, "setCakePerSecond: too many YUMI!");

        // This MUST be done or pool rewards will be calculated with new cake per second
        // This could unfairly punish small pools that dont have frequent deposits/withdraws/harvests
        massUpdatePools();

        cakePerSecond = _cakePerSecond;
    }

    // Update devaddr by the previous devaddr.
    function setDevaddr(address _addr) public {
        require(msg.sender == devaddr, "devaddr: wut?");
        devaddr = _addr;
    }

    // Update reserveaddr by the previous reserveaddr.
    function setReserveaddr(address _addr) public {
        require(msg.sender == reserveaddr, "reserveaddr: wut?");
        reserveaddr = _addr;
    }

    // Update trademining contract
    function setMiningaddr(address _addr) external onlyOwner {
        miningaddr = _addr;
    }
}
