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
        uint256 totalUnits = totalSupply();
        uint256 poolBalance = balanceOf(address(this));
        uint256 dryBalance = totalUnits - poolBalance;
        uint256 poolUnits = 2 * units * poolBalance / totalUnits;
        uint256 dryUnits = 2 * units * dryBalance / totalUnits;
        burnt = units * underlying.balanceOf(address(this)) / dryBalance;
        _burn(address(this), poolUnits);
        _burn(msg.sender, dryUnits);
        IERC20(underlying).safeTransfer(msg.sender, burnt);
    }

    function balances() public view returns (uint256 bu, uint256 poolBalance) {
        bu = balanceOf(address(this));
        poolBalance = ONE.balanceOf(address(this));
    }

    function buyQuote(uint256 bu, uint256 poolBalance, uint256 du) public pure returns (uint256 d1) {
        if (bu <= du) {
            revert InsufficientLiquidity();
        }
        uint256 k = bu * poolBalance;
        uint256 nu = bu - du;
        uint256 n1 = k / nu;
        d1 = poolBalance - n1;
    }

    function sellQuote(uint256 bu, uint256 poolBalance, uint256 du) public pure returns (uint256 d1) {
        uint256 k = bu * poolBalance;
        uint256 nu = bu + du;
        uint256 n1 = k / nu;
        d1 = n1 - poolBalance;
    }

    function buyQuote(uint256 du) public view returns (uint256 bu, uint256 poolBalance, uint256 d1) {
        (bu, poolBalance) = balances();
        d1 = buyQuote(bu, poolBalance, du);
    }

    function buyWithQuote(uint256 d1) public view returns (uint256 bu, uint256 poolBalance, uint256 du) {
        (bu, poolBalance) = balances();
        du = sellQuote(poolBalance, bu, d1);
    }

    function buy(uint256 du) external returns (uint256 bu, uint256 poolBalance, uint256 d1) {
        (bu, poolBalance, d1) = buyQuote(du);
        buyTransfers(du, d1);
    }

    function buyWith(uint256 d1) external returns (uint256 bu, uint256 poolBalance, uint256 du) {
        (bu, poolBalance, du) = buyWithQuote(d1);
        buyTransfers(du, d1);
    }

    function sellQuote(uint256 du) public view returns (uint256 bu, uint256 poolBalance, uint256 d1) {
        (bu, poolBalance) = balances();
        d1 = sellQuote(bu, poolBalance, du);
    }

    function sellForQuote(uint256 d1) public view returns (uint256 bu, uint256 poolBalance, uint256 du) {
        (bu, poolBalance) = balances();
        d1 = buyQuote(poolBalance, bu, du);
    }

    function sell(uint256 du) external returns (uint256 bu, uint256 poolBalance, uint256 d1) {
        (bu, poolBalance, d1) = sellQuote(du);
        sellTransfers(du, d1);
    }

    function sellFor(uint256 d1) external returns (uint256 bu, uint256 poolBalance, uint256 du) {
        (bu, poolBalance, du) = sellForQuote(d1);
        sellTransfers(du, d1);
    }

    function buyTransfers(uint256 du, uint256 d1) private {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(ONE).transfer(address(this), d1);
        _transfer(address(this), msg.sender, du);
    }

    function sellTransfers(uint256 du, uint256 d1) private {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(ONE).transferFrom(address(this), msg.sender, d1);
        _transfer(msg.sender, address(this), du);
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
