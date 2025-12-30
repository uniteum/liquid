// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract Pool is ERC20, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    uint256 constant MAX_SUPPLY = 1e9 ether;

    string public constant ONE_NAME = "Uniteum 1";

    string public constant ONE_SYMBOL = "1";

    string public constant NAME_SUFFIX = " per 1";

    string public constant SYMBOL_SUFFIX = "/1";

    Pool public immutable ONE = this;

    address public immutable ISSUER = 0xEbCaD83FeAD16e7D18DD691fFD2b39eca56677d8;

    IERC20Metadata public underlying = IERC20Metadata(address(0xdeadbeef));

    function mint(uint256 units) external nonReentrant {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), units);
        _mint(address(this), units);
        _mint(msg.sender, units);
    }

    function burn(uint256 units) external nonReentrant returns (uint256 burnt) {
        uint256 total = totalSupply();
        uint256 pool = balanceOf(address(this));
        uint256 dry = total - pool;
        uint256 myPool = 2 * units * pool / total;
        uint256 myDry = 2 * units * dry / total;
        burnt = units * underlying.balanceOf(address(this)) / dry;
        _burn(address(this), myPool);
        _burn(msg.sender, myDry);
        IERC20(underlying).safeTransfer(msg.sender, burnt);
    }

    function balances() public view returns (uint256 pool, uint256 ones) {
        pool = balanceOf(address(this));
        ones = ONE.balanceOf(address(this));
    }

    function buyQuote(uint256 pool, uint256 ones, uint256 units) public pure returns (uint256 myOnes) {
        if (pool <= units) {
            revert InsufficientLiquidity();
        }
        uint256 k = pool * ones;
        uint256 newPool = pool - units;
        uint256 newOnes = k / newPool;
        myOnes = ones - newOnes;
    }

    function sellQuote(uint256 pool, uint256 ones, uint256 units) public pure returns (uint256 myOnes) {
        uint256 k = pool * ones;
        uint256 newPool = pool + units;
        uint256 newOnes = k / newPool;
        myOnes = newOnes - ones;
    }

    function buyQuote(uint256 units) public view returns (uint256 pool, uint256 ones, uint256 myOnes) {
        (pool, ones) = balances();
        myOnes = buyQuote(pool, ones, units);
    }

    function buyWithQuote(uint256 myOnes) public view returns (uint256 pool, uint256 ones, uint256 units) {
        (pool, ones) = balances();
        units = sellQuote(ones, pool, myOnes);
    }

    function buy(uint256 units) external returns (uint256 pool, uint256 ones, uint256 myOnes) {
        (pool, ones, myOnes) = buyQuote(units);
        buyTransfers(units, myOnes);
    }

    function buyWith(uint256 myOnes) external returns (uint256 pool, uint256 ones, uint256 units) {
        (pool, ones, units) = buyWithQuote(myOnes);
        buyTransfers(units, myOnes);
    }

    function sellQuote(uint256 units) public view returns (uint256 pool, uint256 ones, uint256 myOnes) {
        (pool, ones) = balances();
        myOnes = sellQuote(pool, ones, units);
    }

    function sellForQuote(uint256 myOnes) public view returns (uint256 pool, uint256 ones, uint256 units) {
        (pool, ones) = balances();
        myOnes = buyQuote(ones, pool, units);
    }

    function sell(uint256 units) external returns (uint256 pool, uint256 ones, uint256 myOnes) {
        (pool, ones, myOnes) = sellQuote(units);
        sellTransfers(units, myOnes);
    }

    function sellFor(uint256 myOnes) external returns (uint256 pool, uint256 ones, uint256 units) {
        (pool, ones, units) = sellForQuote(myOnes);
        sellTransfers(units, myOnes);
    }

    function buyTransfers(uint256 units, uint256 myOnes) private {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(ONE).transfer(address(this), myOnes);
        _transfer(address(this), msg.sender, units);
    }

    function sellTransfers(uint256 units, uint256 myOnes) private {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(ONE).transferFrom(address(this), msg.sender, myOnes);
        _transfer(msg.sender, address(this), units);
    }

    function name() public view virtual override returns (string memory) {
        return this == ONE ? ONE_NAME : string.concat(underlying.name(), NAME_SUFFIX);
    }

    function symbol() public view virtual override returns (string memory) {
        return this == ONE ? ONE_SYMBOL : string.concat(underlying.symbol(), SYMBOL_SUFFIX);
    }

    function predict(IERC20Metadata underlying_) public view returns (address predicted, bytes32 newSalt) {
        if (address(underlying_) == address(0)) {
            revert UnderlyingNull();
        }
        newSalt = bytes32(uint256(uint160(address(underlying_))));
        predicted = Clones.predictDeterministicAddress(address(ONE), newSalt, address(ONE));
    }

    function clone(IERC20Metadata underlying_) public returns (address instance) {
        if (this == ONE) {
            bytes32 newSalt;
            (instance, newSalt) = predict(underlying_);

            if (instance.code.length == 0) {
                instance = Clones.cloneDeterministic(address(ONE), newSalt);
                Pool(instance).__initialize(underlying_);
            }
        } else {
            instance = ONE.clone(underlying_);
        }
    }

    function __initialize(IERC20Metadata underlying_) public {
        if (address(underlying) == address(0)) {
            underlying = underlying_;
        }
    }

    constructor() ERC20("", "") {
        _mint(ISSUER, MAX_SUPPLY);
    }

    error UnderlyingNull();
    error InsufficientLiquidity();
}
