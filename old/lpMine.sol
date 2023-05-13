// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./contracts/access/Ownable.sol";
import "./contracts/math/SafeMath.sol";
import "./contracts/token/ERC20/SafeERC20.sol";
import "./IUniswapV2Router02.sol";


contract lpMine is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 LPAmount; // How many LP or TOKEN tokens the user has provided.
        uint256 totalWithdrawUSDT;
        uint256 totalWithdrawIGS;
        uint256 usdtAmount;
        uint256 igsAmount;
        
        uint256 assumedIGSDividends;
        uint256 assumedUSDTDividends;

        uint256 igsDividendsDebt;
        uint256 usdtDividendsDebt;
    }

    struct PoolInfo {
        address lpToken; // Address of LP or TOKEN token contract.
        uint256 totalLp;
        address dividendPoolAddress;
        uint256 totalAssumedIGSDividends;
        uint256 totalAssumedUSDTDividends;
        uint256 totalDeptIGSDividends;
        uint256 totalDeptIGSDividendsByRemoveLp;
        uint256 totalDeptUSDTDividends;
        uint256 totalDeptUSDTDividendsByRemoveLp;
    }
    address public igsTokenAddress;
    address public usdtTokenAddress;
    address public defaultReferrerAddress=0xebdeA78F37588752AFED1681C8E068F23CFEc010;

    uint256 public tokenPerBlock;

    uint public lastUserId=1;

    ranking[] public rankingList;

    mapping(address => Player) public playerInfo;

    struct ranking{
           address addr;
           uint256 usdtAmount;
    }


    // Info of each pool.
    PoolInfo[] public poolInfos;
    mapping(address => mapping(uint256 => uint256)) public lpTokenRegistry;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;


    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    
    event WithdrawIGSDividends(address indexed sender, address indexed recipient, uint256 amount);
    event WithdrawUSDTDividends(address indexed sender, address indexed recipient, uint256 amount);
    
    
    struct Player {
        uint256 id;
        address[] directRecommendAddress;
        address referrer;
        uint256 totalDepositOfDirectRecommend;
    }
    
    mapping(address => reward) public referralRewards;

    struct reward{
        uint usdtReward;
        uint igsReward;
    }

    IUniswapV2Router02 public uniswapV2Router;

    constructor() public {
        igsTokenAddress=0xD4AA889d3690b52aB4a1a5090142f133834358f2;
        usdtTokenAddress=0x55d398326f99059fF775485246999027B3197955;
        uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    }

    // ============ Modifiers ============

   modifier lpTokenExist(address _lpToken,uint256 _poolIndex) {
        require(lpTokenRegistry[_lpToken][_poolIndex] > 0, "Airdrop: LP token not exist");
        _;
    }

    modifier lpTokenNotExist(address _lpToken,uint256 _poolIndex) {
        require(
            lpTokenRegistry[_lpToken][_poolIndex] == 0,
            "Airdrop: LP token already exist"
        );
        _;
    }

    // ============ Helper ============

    function poolLength() external view returns (uint256) {
        return poolInfos.length;
    }

    function getPid(address _lpToken,uint256 _poolIndex)
        public
        view
        lpTokenExist(_lpToken,_poolIndex)
        returns (uint256)
    {
        return lpTokenRegistry[_lpToken][_poolIndex] - 1;
    }

    function getUserLpBalance(address _lpToken, address _user,uint256 _poolIndex)
        public
        view
        returns (uint256)
    {
        uint256 pid = getPid(_lpToken,_poolIndex);
        return userInfo[pid][_user].LPAmount;
    }

    // ============ Ownable ============

    
    function addLpToken(
        address _lpToken,
        address _dividendPoolAddress,
        uint256 _poolIndex
    ) public lpTokenNotExist(_lpToken,_poolIndex) onlyOwner {
        require(_lpToken != address(0), "Airdrop: zero address not allowed");
        
        poolInfos.push(
            PoolInfo({
                lpToken: _lpToken,
                totalLp:0,
                dividendPoolAddress: _dividendPoolAddress,
                totalAssumedIGSDividends:0,
                totalAssumedUSDTDividends:0,
                totalDeptIGSDividends:0,
                totalDeptIGSDividendsByRemoveLp:0,
                totalDeptUSDTDividends:0,
                totalDeptUSDTDividendsByRemoveLp:0
            })
        );
        lpTokenRegistry[_lpToken][_poolIndex] = poolInfos.length;
    }



    function setIGSTokenAddress(address _addr) public onlyOwner(){
           igsTokenAddress=_addr;
    }
    function setUSDTTokenAddress(address _addr) public onlyOwner(){
           usdtTokenAddress=_addr;
    }

    function updateFee(address _lpToken, uint256 _amount,uint256 _poolIndex) private{
        uint256 pid = getPid(_lpToken,_poolIndex);
        PoolInfo storage pool = poolInfos[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 IGSFeeBalance = IERC20(igsTokenAddress).balanceOf(pool.dividendPoolAddress).add(pool.totalAssumedIGSDividends).add(pool.totalDeptIGSDividends).sub(pool.totalDeptIGSDividendsByRemoveLp);
        uint256 USDTFeeBalance = IERC20(usdtTokenAddress).balanceOf(pool.dividendPoolAddress).add(pool.totalAssumedUSDTDividends).add(pool.totalDeptUSDTDividends).sub(pool.totalDeptUSDTDividendsByRemoveLp);
        uint256 oldTotalLp=pool.totalLp;
        uint256 newTotalLp=oldTotalLp.add(_amount);
        
        uint256 newAssumedIGSDividends;
        uint256 newAssumedUSDTDividends;
        if (oldTotalLp!=0){
            newAssumedIGSDividends=IGSFeeBalance.mul(newTotalLp).div(oldTotalLp).sub(IGSFeeBalance);
            newAssumedUSDTDividends=USDTFeeBalance.mul(newTotalLp).div(oldTotalLp).sub(USDTFeeBalance);
        }else{
            newAssumedIGSDividends=0;
            newAssumedIGSDividends=0;
        }

        user.assumedIGSDividends=user.assumedIGSDividends.add(newAssumedIGSDividends);
        pool.totalAssumedIGSDividends=pool.totalAssumedIGSDividends.add(newAssumedIGSDividends);
        
        user.assumedUSDTDividends=user.assumedUSDTDividends.add(newAssumedUSDTDividends);
        pool.totalAssumedUSDTDividends=pool.totalAssumedUSDTDividends.add(newAssumedUSDTDividends);  
    }
    

    function getIGSDividends(address _user,address _lpToken,uint256 _poolIndex) public view returns(uint256){
        uint256 pid = getPid(_lpToken,_poolIndex);
        PoolInfo storage pool = poolInfos[pid];
        UserInfo storage user = userInfo[pid][_user];
        uint256 igsFeeBalance = IERC20(igsTokenAddress).balanceOf(pool.dividendPoolAddress).add(pool.totalAssumedIGSDividends).add(pool.totalDeptIGSDividends).sub(pool.totalDeptIGSDividendsByRemoveLp);
        uint256 totalLp=pool.totalLp;
        uint256 lpBalance=getUserLpBalance(_lpToken,_user,_poolIndex);
        
        if (totalLp==0){
            return 0;
        }
        return lpBalance.mul(igsFeeBalance).div(totalLp).sub(user.assumedIGSDividends.add(user.igsDividendsDebt));
    }

    function getUSDTDividends(address _user,address _lpToken,uint256 _poolIndex) public  view returns(uint256){
        uint256 pid = getPid(_lpToken,_poolIndex);
        PoolInfo storage pool = poolInfos[pid];
        UserInfo storage user = userInfo[pid][_user];
        uint256 usdtFeeBalance = IERC20(usdtTokenAddress).balanceOf(pool.dividendPoolAddress).add(pool.totalAssumedUSDTDividends).add(pool.totalDeptUSDTDividends).sub(pool.totalDeptUSDTDividendsByRemoveLp);
        uint256 totalLp=pool.totalLp;
        uint256 lpBalance=getUserLpBalance(_lpToken,_user,_poolIndex);
        if (totalLp==0){
            return 0;
        }
        return lpBalance.mul(usdtFeeBalance).div(totalLp).sub(user.assumedUSDTDividends.add(user.usdtDividendsDebt));
    }

    function withdrawIGSDividends(address _lpToken,uint256 _poolIndex)public returns(uint256){
        require(msg.sender == tx.origin,"Address: The transferred address cannot be a contract");
        uint256 pid = getPid(_lpToken,_poolIndex);
        PoolInfo storage pool = poolInfos[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 igsDividendsBalance=getIGSDividends(msg.sender,_lpToken,_poolIndex);

        require(igsDividendsBalance!=0);

        address referalAddress=getReferralRelationship(msg.sender);
        if(getReferralRelationship(msg.sender)!=address(0)&&userInfo[pid][referalAddress].usdtAmount>1990*10**18&&pid==0){
            IERC20(igsTokenAddress).transferFrom(pool.dividendPoolAddress,address(msg.sender),igsDividendsBalance.mul(90).div(100));
            uint256 referrerFee = igsDividendsBalance.mul(10).div(100);
            referralRewards[referalAddress].igsReward=  referralRewards[referalAddress].igsReward.add(referrerFee);
            IERC20(igsTokenAddress).transferFrom(pool.dividendPoolAddress,referalAddress,referrerFee);
        }else{
            IERC20(igsTokenAddress).transferFrom(pool.dividendPoolAddress,address(msg.sender),igsDividendsBalance);
        }
        user.igsDividendsDebt=user.igsDividendsDebt.add(igsDividendsBalance);
        pool.totalDeptIGSDividends=pool.totalDeptIGSDividends.add(igsDividendsBalance);
        user.totalWithdrawIGS=user.totalWithdrawIGS.add(igsDividendsBalance);
        emit WithdrawIGSDividends(pool.dividendPoolAddress, msg.sender, igsDividendsBalance);
        return (user.igsDividendsDebt);
    }

    function withdrawUSDTDividends(address _lpToken,uint256 _poolIndex)public returns(uint256){
        require(msg.sender == tx.origin,"Address: The transferred address cannot be a contract");
        uint256 pid = getPid(_lpToken,_poolIndex);
        PoolInfo storage pool = poolInfos[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 usdtDividendsBalance=getUSDTDividends(msg.sender,_lpToken,_poolIndex);
        require(usdtDividendsBalance!=0);
        
        address referalAddress=getReferralRelationship(msg.sender);
        if(getReferralRelationship(msg.sender)!=address(0)&&userInfo[pid][referalAddress].usdtAmount>1990*10**18&&pid==0){
            IERC20(usdtTokenAddress).transferFrom(pool.dividendPoolAddress,address(msg.sender),usdtDividendsBalance.mul(90).div(100));
            uint256 referrerFee = usdtDividendsBalance.mul(10).div(100);
            referralRewards[referalAddress].usdtReward = referralRewards[referalAddress].usdtReward.add(referrerFee);

            IERC20(usdtTokenAddress).transferFrom(pool.dividendPoolAddress,referalAddress,referrerFee);
            
        }else{
            IERC20(usdtTokenAddress).transferFrom(pool.dividendPoolAddress,address(msg.sender),usdtDividendsBalance);
        }
        user.usdtDividendsDebt=user.usdtDividendsDebt.add(usdtDividendsBalance);
        pool.totalDeptUSDTDividends=pool.totalDeptUSDTDividends.add(usdtDividendsBalance);
        user.totalWithdrawUSDT=user.totalWithdrawUSDT.add(usdtDividendsBalance);
        emit WithdrawUSDTDividends(pool.dividendPoolAddress, msg.sender, usdtDividendsBalance);
        
        return (user.usdtDividendsDebt);
    }

    // ============ Deposit & Withdraw & Claim ============

    function deposit(address _lpToken, uint256 _amount) public {
        require(msg.sender == tx.origin,"Address: The transferred address cannot be a contract");
        require(isUserExists(msg.sender),"you are not registered");
        uint256 pid = getPid(_lpToken,1);
        PoolInfo storage pool = poolInfos[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        updateFee(_lpToken,_amount,1);
        require(_amount>0,"_amount error");
        uint256 usdtbyLp=consult(_lpToken,_amount);
            IERC20(pool.lpToken).safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
        pool.totalLp=pool.totalLp.add(_amount);
        user.LPAmount = user.LPAmount.add(_amount);
        user.usdtAmount=user.usdtAmount.add(usdtbyLp.mul(2));
        if(user.usdtAmount>=19900*10**18){
            uint256 pid2 = getPid(_lpToken,2);
            PoolInfo storage pool2 = poolInfos[pid2];
            UserInfo storage user2 = userInfo[pid2][msg.sender];
            if(user2.LPAmount==0){
                updateFee(_lpToken,user.LPAmount,2);
                pool2.totalLp=pool2.totalLp.add(user.LPAmount);
            }else{
                updateFee(_lpToken,_amount,2);
                pool2.totalLp=pool2.totalLp.add(_amount);
            }
            user2.LPAmount=user.LPAmount;
            user2.usdtAmount=user.usdtAmount;
        }

        address referrer =getReferralRelationship(msg.sender);
        playerInfo[referrer].totalDepositOfDirectRecommend=playerInfo[referrer].totalDepositOfDirectRecommend.add(_amount);
        
        emit Deposit(msg.sender, pid, _amount);
    }

    function combinedLP(address _lpToken,uint256 _poolIndex) private returns(uint256 newLPBalance){
        uint256 pid = getPid(_lpToken,_poolIndex);
        PoolInfo storage pool = poolInfos[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 usdtDividendsBalance=getUSDTDividends(msg.sender,_lpToken,_poolIndex);
        uint256 igsDividendsBalance=getIGSDividends(msg.sender,_lpToken,_poolIndex);

        IERC20(usdtTokenAddress).transferFrom(pool.dividendPoolAddress,address(this),usdtDividendsBalance);
        IERC20(igsTokenAddress).transferFrom(pool.dividendPoolAddress,address(this),igsDividendsBalance);
        user.usdtDividendsDebt=user.usdtDividendsDebt.add(usdtDividendsBalance);
        user.igsDividendsDebt=user.igsDividendsDebt.add(igsDividendsBalance);
        pool.totalDeptUSDTDividends=pool.totalDeptUSDTDividends.add(usdtDividendsBalance);
        pool.totalDeptIGSDividends=pool.totalDeptIGSDividends.add(igsDividendsBalance);
        user.totalWithdrawIGS=user.totalWithdrawIGS.add(igsDividendsBalance);
        user.totalWithdrawUSDT=user.totalWithdrawUSDT.add(usdtDividendsBalance);


        if(IERC20(igsTokenAddress).balanceOf(address(this))>0){
            address[] memory path = new address[](2);
            path[0] = igsTokenAddress;
            path[1] = usdtTokenAddress;
            swapTokensForExactTokens(IERC20(igsTokenAddress).balanceOf(address(this)),path);
        }

        uint256 initialLPBalance = IERC20(pool.lpToken).balanceOf(address(this));

        swapAndLiquify(IERC20(usdtTokenAddress).balanceOf(address(this)));
        return newLPBalance = IERC20(pool.lpToken).balanceOf(address(this)).sub(initialLPBalance);
    }

    function reDeposit(address _lpToken,uint256 _poolIndex) public  {
        require(msg.sender == tx.origin,"Address: The transferred address cannot be a contract");
        require(isUserExists(msg.sender),"you are not registered");
        uint256 LPBalance=combinedLP(_lpToken,_poolIndex);

        uint256 pid = getPid(_lpToken,1);
        PoolInfo storage pool = poolInfos[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        updateFee(_lpToken,LPBalance,1);   
        uint256 usdtbyLp=consult(_lpToken,LPBalance);
        pool.totalLp=pool.totalLp.add(LPBalance);
        user.LPAmount = user.LPAmount.add(LPBalance);
        user.usdtAmount=user.usdtAmount.add(usdtbyLp.mul(2));
        if(user.usdtAmount>=19900*10**18){
            uint256 pid2 = getPid(_lpToken,2);
            PoolInfo storage pool2 = poolInfos[pid2];
            UserInfo storage user2 = userInfo[pid2][msg.sender];
            if(user2.LPAmount==0){
                updateFee(_lpToken,user.LPAmount,2);
                pool2.totalLp=pool2.totalLp.add(user.LPAmount);
            }else{
                updateFee(_lpToken,LPBalance,2);
                pool2.totalLp=pool2.totalLp.add(LPBalance);
            }
            user2.LPAmount=user.LPAmount;
            user2.usdtAmount=user.usdtAmount;
        }
        address referrer =getReferralRelationship(msg.sender);
        playerInfo[referrer].totalDepositOfDirectRecommend=playerInfo[referrer].totalDepositOfDirectRecommend.add(LPBalance);
        emit Deposit(msg.sender, pid, LPBalance);
    }

    function withdraw(address _lpToken) public {
        require(msg.sender == tx.origin,"Address: The transferred address cannot be a contract");
        require(isUserExists(msg.sender),"you are not registered");
        uint256 pid = getPid(_lpToken,1);
        PoolInfo storage pool = poolInfos[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        if (user.LPAmount > 0) {
            IERC20(pool.lpToken).safeTransfer(address(msg.sender), user.LPAmount);
            address referrer =getReferralRelationship(msg.sender);
            playerInfo[referrer].totalDepositOfDirectRecommend=playerInfo[referrer].totalDepositOfDirectRecommend.sub(user.LPAmount); 
        }
        if (user.usdtAmount > 19900*10**18) {
            uint256 pid2 = getPid(_lpToken,2);
            PoolInfo storage pool2 = poolInfos[pid2];
            UserInfo storage user2 = userInfo[pid2][msg.sender];
            pool2.totalLp=pool2.totalLp.sub(user2.LPAmount);
            user2.LPAmount = 0;
            user2.usdtAmount=0;
            pool2.totalDeptIGSDividendsByRemoveLp=pool2.totalDeptIGSDividendsByRemoveLp.add(user2.igsDividendsDebt);
            pool2.totalAssumedIGSDividends=pool2.totalAssumedIGSDividends.sub(user2.assumedIGSDividends);
            user2.assumedIGSDividends=0;
            user2.igsDividendsDebt=0;
            pool2.totalAssumedUSDTDividends=pool2.totalAssumedUSDTDividends.sub(user2.assumedUSDTDividends);
            pool2.totalDeptUSDTDividendsByRemoveLp=pool2.totalDeptUSDTDividendsByRemoveLp.add(user2.usdtDividendsDebt);
            user2.assumedUSDTDividends=0;
            user2.usdtDividendsDebt=0;
        }
        pool.totalLp=pool.totalLp.sub(user.LPAmount);
        pool.totalDeptIGSDividendsByRemoveLp=pool.totalDeptIGSDividendsByRemoveLp.add(user.igsDividendsDebt);
        pool.totalAssumedIGSDividends=pool.totalAssumedIGSDividends.sub(user.assumedIGSDividends);
        user.assumedIGSDividends=0;
        user.igsDividendsDebt=0;
        pool.totalAssumedUSDTDividends=pool.totalAssumedUSDTDividends.sub(user.assumedUSDTDividends);
        pool.totalDeptUSDTDividendsByRemoveLp=pool.totalDeptUSDTDividendsByRemoveLp.add(user.usdtDividendsDebt);
        user.LPAmount = 0;
        user.usdtAmount=0;
        user.assumedUSDTDividends=0;
        user.usdtDividendsDebt=0;
        emit Withdraw(msg.sender, pid, user.LPAmount);
    }
    function isUserExists(address user) public view returns (bool) {
        return (playerInfo[user].id != 0);
    }

    function bind(address _referrerAddress) public {
        require(msg.sender == tx.origin,"Address: The transferred address cannot be a contract");
        bool isExists =isUserExists(msg.sender);
        if(isExists){
            return;
        }
        require(isUserExists(_referrerAddress)||_referrerAddress==defaultReferrerAddress,"ReferrerAddress don't exist");
        Player storage player=playerInfo[msg.sender];
        if (!isExists){
            player.id=lastUserId;
            player.referrer=_referrerAddress;
            lastUserId++;
            playerInfo[_referrerAddress].directRecommendAddress.push(msg.sender);
         }
    }

    function getDirectRecommendAddress(address user) public view returns(address[] memory){
        return playerInfo[user].directRecommendAddress;
    }

    function getReferralRelationship(address user) public view returns(address){
        return playerInfo[user].referrer;
    }

    function consult(address _lpToken, uint256 _amountIn) public view returns (uint256 amountOut) {
        uint USDTBalance = IERC20(usdtTokenAddress).balanceOf(_lpToken);
        uint _totalSupply =IERC20(_lpToken).totalSupply();
        uint amount0 = _amountIn.mul(USDTBalance).div(_totalSupply);
        return amount0;
    }

    function getPrice() public view returns (uint){

        address[] memory path = new address[](2);
	    path[0] = igsTokenAddress;
	    path[1] = usdtTokenAddress;

        uint[] memory amount1 = uniswapV2Router.getAmountsOut(1*10**18,path);

        return amount1[1];
    }

    function swapAndLiquify(uint256 contractTokenBalance) private{
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);
        uint256 initialBalance = IERC20(igsTokenAddress).balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = usdtTokenAddress;
        path[1] = igsTokenAddress;
        swapTokensForExactTokens(half,path); 
        uint256 newBalance = IERC20(igsTokenAddress).balanceOf(address(this)).sub(initialBalance);


        addLiquidity(otherHalf,newBalance);
    }

    function swapTokensForExactTokens(uint256 tokenAmount,address[] memory path) private {

        IERC20(igsTokenAddress).approve(
                address(uniswapV2Router),
                tokenAmount
        );
        IERC20(usdtTokenAddress).approve(
                address(uniswapV2Router),
                tokenAmount
        );
        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }
    function addLiquidity(uint256 usdtAmount,uint256 tokenAmount) private{

        IERC20(usdtTokenAddress).approve(
                address(uniswapV2Router),
                usdtAmount
        );
        IERC20(igsTokenAddress).approve(
                address(uniswapV2Router),
                tokenAmount
        );
        
        // add the liquidity
        uniswapV2Router.addLiquidity(
            address(usdtTokenAddress),
            address(igsTokenAddress),
            usdtAmount,
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

}