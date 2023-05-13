// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

abstract contract ERC20 is IERC20, Ownable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint;

    ISwapRouter private constant SWAP_ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    mapping (address => uint) public _balances;

    mapping (address => mapping (address => uint)) private _allowances;

    uint private _totalSupply;
    
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    uint public _addPriceTokenAmount = 1e14;
   
    uint256 public _marketingFee = 50;
    uint256 private _previousMarketingFee = _marketingFee;

    uint256 public _lpDividendsFee = 450;
    uint256 private _previousLPDividendsFee = _lpDividendsFee;

    uint256 public _lpFeeAddress2Dividends = 45;
    uint256 public _previousLPFeeAddress2Dividends = _lpFeeAddress2Dividends;

    address public _weth9Address = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    address public _marketingAddress = 0xebdeA78F37588752AFED1681C8E068F23CFEc010;

    address public _lpFeeAddress1 = 0xCCF5B6C077996ba12f63b283c5c8335ADCdfEe66;
    address public _lpFeeAddress2 = 0x754B23eEcF1e14466434492384cFA2d8CF61075A;

    IUniswapV3Factory public immutable _uniswapV3Factory;
    IUniswapV3Pool public immutable _uniswapV3Pool;
    uint24 public _fee = 3000;

    bool public _isCreatePool;

    mapping (address => bool) private _isExcludedFromFee;
    bool private _inSwapAndLiquify;
    
    modifier lockTheSwap {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }
    
    constructor (string memory name_, string memory symbol_, uint8 decimals_, uint totalSupply_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _totalSupply = totalSupply_;

        require(_weth9Address < address(this));

        _uniswapV3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        _uniswapV3Pool = IUniswapV3Pool(_uniswapV3Factory.createPool(_weth9Address, address(this), _fee));

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_lpFeeAddress1] = true;
        _isExcludedFromFee[_lpFeeAddress2] = true;
        _isExcludedFromFee[_marketingAddress] = true;
    }

    function name() public view returns (string memory) {
        return _name;
    }
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint) {
        return _totalSupply;
    }
    function balanceOf(address account) public view override returns (uint) {
        return _balances[account];
    }
    function transfer(address recipient, uint amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view override returns (uint) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
    function increaseAllowance(address spender, uint addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }
    function decreaseAllowance(address spender, uint subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function setLPDividendsFeePercent(uint256 lpDividendsFee_) external onlyOwner() {
        _lpDividendsFee = lpDividendsFee_;
    }

    function setMarketingAddress(address marketingAddress_) external onlyOwner() {
        _marketingAddress = marketingAddress_;
    }

    function setMarketingFeePercent(uint256 marketingFeeFee_) external onlyOwner() {
        _marketingFee = marketingFeeFee_;
    }

    function setAddPriceTokenAmount(uint addPriceTokenAmount_)external onlyOwner{
        _addPriceTokenAmount = addPriceTokenAmount_;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        
        uint256 igsbalance = balanceOf(address(this));
        bool overMinTokenBalance = igsbalance >= 1*10**18;

        if (
            overMinTokenBalance &&
            !_inSwapAndLiquify &&
            from != address(_uniswapV3Pool)
        ) {
            _swapTokensForExactTokens(igsbalance);
        }

        if(
            _isExcludedFromFee[from] || 
            _isExcludedFromFee[to] ||
            (from != address(_uniswapV3Pool) && to != address(_uniswapV3Pool))
        ){
            _removeAllFee();
        }

        uint256 lpDividendsFee;
        uint256 marketingFee;
        
        if (from == address(_uniswapV3Pool)){
            marketingFee = _calculateMarketingFee(amount);
            _takeMarketingFee(from, marketingFee);
            lpDividendsFee= _calculateLPDividendsFee(amount);
            _takeLPDividendsFeeOfBuy(from, lpDividendsFee);
        } else if (to == address(_uniswapV3Pool)){
            marketingFee = _calculateMarketingFee(amount);
            _takeMarketingFee(from, marketingFee);
            lpDividendsFee = _calculateLPDividendsFee(amount);
            _takeLPDividendsFeeOfSell(from,lpDividendsFee);
        }

        _balances[from] = _balances[from].sub(amount, "ERC20: transfer amount exceeds balance");
        uint256 trunAmount = amount.sub(lpDividendsFee).sub(marketingFee);
        _balances[to] = _balances[to].add(trunAmount);
        emit Transfer(from, to, trunAmount);
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]||(from!=address(_uniswapV3Pool)&&to!=address(_uniswapV3Pool))){
            _restoreAllFee();
        }
        if (to==address(_uniswapV3Pool)&&!_isCreatePool){
            require(from == owner());
            _isCreatePool = true;
        }
    }

    function _approve(address owner, address spender, uint amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _swapTokensForExactTokens(uint256 tokenAmount_) private lockTheSwap{
        address owner = owner();
        _approve(owner, address(SWAP_ROUTER), tokenAmount_);
        // make the swap
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
            owner,
            _weth9Address,
            _fee,
            address(_lpFeeAddress1),
            block.timestamp + 15,
            tokenAmount_.mul(_lpDividendsFee.sub(_lpFeeAddress2Dividends)).div(_lpDividendsFee),
            0,
            0
        );
        SWAP_ROUTER.exactInputSingle(params);

        params.recipient = address(_lpFeeAddress2);
        params.amountIn = tokenAmount_.mul(_lpFeeAddress2Dividends).div(_lpDividendsFee);
        params.deadline = block.timestamp + 15;
        SWAP_ROUTER.exactInputSingle(params);
    }

    function _removeAllFee() private {
        if(_marketingFee == 0 && _lpDividendsFee == 0 && _lpFeeAddress2Dividends == 0) return;
        
        _previousMarketingFee = _marketingFee; 
        _previousLPDividendsFee=_lpDividendsFee;
        _previousLPFeeAddress2Dividends=_lpFeeAddress2Dividends;
        _marketingFee=0;
        _lpDividendsFee=0;
        _lpFeeAddress2Dividends=0;
    }

    function _restoreAllFee() private {
        _marketingFee=_previousMarketingFee;
        _lpDividendsFee=_previousLPDividendsFee;
        _lpFeeAddress2Dividends=_previousLPFeeAddress2Dividends;
    }

    function _calculateMarketingFee(uint256 amount_) private view returns (uint256) {
        return amount_.mul(_marketingFee).div(
            10**4
        );
    }

    function _calculateLPDividendsFee(uint256 amount_) private view returns (uint256) {
        return amount_.mul(_lpDividendsFee).div(
            10**4
        );
    }

    function _takeMarketingFee(address from_, uint256 marketingFee_) private {
        if(marketingFee_ == 0)return;

        _balances[_marketingAddress] = _balances[_marketingAddress].add(marketingFee_);  
        emit Transfer(from_, _marketingAddress, marketingFee_);
    }

    function _takeLPDividendsFeeOfBuy(address from_, uint256 lpDividends_) private {
        if (lpDividends_ == 0)return;

        _balances[address(this)] = _balances[address(this)].add(lpDividends_);  
        emit Transfer(from_, address(this), lpDividends_);
    }

    function _takeLPDividendsFeeOfSell(address from_, uint256 lpDividends_) private {
        if (lpDividends_ == 0)return;

        _balances[_lpFeeAddress1] = _balances[_lpFeeAddress1].add(lpDividends_.mul(_lpDividendsFee.sub(_lpFeeAddress2Dividends)).div(_lpDividendsFee));

        emit Transfer(from_, _lpFeeAddress1, lpDividends_.mul(_lpDividendsFee.sub(_lpFeeAddress2Dividends)).div(_lpDividendsFee));
        _balances[_lpFeeAddress2] = _balances[_lpFeeAddress2].add(lpDividends_.mul(_lpFeeAddress2Dividends).div(_lpDividendsFee));

        emit Transfer(from_, _lpFeeAddress2, lpDividends_.mul(_lpFeeAddress2Dividends).div(_lpDividendsFee));
    }

    receive() external payable {}

}

contract IGSToken is ERC20 {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint;
    constructor () ERC20("iGameS", "IGS", 18, 840000*10**18) {
        _balances[msg.sender] = totalSupply();
        emit Transfer(address(0),msg.sender, totalSupply());
    }
}