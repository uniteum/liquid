// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.30;

import {ERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract Liquid is ERC20, ReentrancyGuardTransient {
    using SafeERC20 for IERC20Metadata;

    Liquid public immutable WATER = this;

    IERC20Metadata public solid;
    mapping(address => IERC20Metadata) public solidOf;

    constructor(IERC20Metadata ice) ERC20("", "") {
        solid = ice;
        solidOf[address(this)] = ice;
    }

    function heat(uint256 cold) external nonReentrant {
        solid.safeTransferFrom(msg.sender, address(this), cold);
        _mint(address(this), cold);
        _mint(msg.sender, cold);
        emit Liquify(this, cold);
    }

    function cool(uint256 hot) external nonReentrant returns (uint256 cold) {
        uint256 total = totalSupply();
        uint256 pool = balanceOf(address(this));
        uint256 held = total - pool;
        uint256 ours = 2 * hot * pool / total;
        uint256 mine = 2 * hot * held / total;
        cold = hot * solid.balanceOf(address(this)) / held;
        _burn(address(this), ours);
        _burn(msg.sender, mine);
        solid.safeTransfer(msg.sender, cold);
        emit Solidify(this, hot, cold);
    }

    function balances() public view returns (uint256 pool, uint256 lake) {
        pool = balanceOf(address(this));
        lake = WATER.balanceOf(address(this));
    }

    function buyQuote(uint256 hot, uint256 pool, uint256 lake) public view returns (uint256 water) {
        if (pool <= hot) {
            revert Drained(this, pool, hot);
        }
        uint256 drained = pool - hot;
        uint256 filled = pool * lake / drained;
        water = filled - lake;
    }

    function sellQuote(uint256 hot, uint256 pool, uint256 lake) public pure returns (uint256 water) {
        uint256 filled = pool + hot;
        uint256 drained = pool * lake / filled;
        water = lake - drained;
    }

    function buyQuote(uint256 hot) public view returns (uint256 water) {
        (uint256 pool, uint256 lake) = balances();
        water = buyQuote(hot, pool, lake);
    }

    function sellQuote(uint256 hot) public view returns (uint256 water) {
        (uint256 pool, uint256 lake) = balances();
        water = sellQuote(hot, pool, lake);
    }

    function buyQuote(uint256 hot, Liquid other) public view returns (uint256 water, uint256 others) {
        water = buyQuote(hot);
        others = other.buyWithQuote(water);
    }

    function sellQuote(uint256 hot, Liquid other) public view returns (uint256 water, uint256 others) {
        water = sellQuote(hot);
        others = other.sellForQuote(water);
    }

    function buyWithQuote(uint256 water) public view returns (uint256 hot) {
        (uint256 pool, uint256 lake) = balances();
        hot = sellQuote(water, lake, pool);
    }

    function sellForQuote(uint256 water) public view returns (uint256 hot) {
        (uint256 pool, uint256 lake) = balances();
        water = buyQuote(hot, lake, pool);
    }

    function buyWithQuote(uint256 others, Liquid other) public view returns (uint256 water, uint256 hot) {
        water = buyWithQuote(others);
        hot = other.buyWithQuote(water);
    }

    function sellForQuote(uint256 others, Liquid other) public view returns (uint256 water, uint256 hot) {
        water = sellForQuote(others);
        hot = other.sellForQuote(water);
    }

    function buy(uint256 hot) external returns (uint256 water) {
        water = buyQuote(hot);
        _bought(hot, water);
    }

    function sell(uint256 hot) external returns (uint256 water) {
        water = sellQuote(hot);
        _sold(hot, water);
    }

    function buy(uint256 hot, Liquid other) external returns (uint256 water, uint256 others) {
        (water, others) = buyQuote(hot, other);
        other.sold(others, water);
        _bought(hot, water);
    }

    function sell(uint256 hot, Liquid other) external returns (uint256 water, uint256 others) {
        (water, others) = sellQuote(hot, other);
        _sold(hot, water);
        other.bought(others, water);
    }

    function buyWith(uint256 water) external returns (uint256 hot) {
        hot = buyWithQuote(water);
        _bought(hot, water);
    }

    function sellFor(uint256 water) external returns (uint256 hot) {
        hot = sellForQuote(water);
        _sold(hot, water);
    }

    function buyWith(uint256 others, Liquid other) external returns (uint256 water, uint256 hot) {
        (water, hot) = buyWithQuote(others, other);
        other.sold(others, water);
        _bought(hot, water);
    }

    function sellFor(uint256 others, Liquid other) external returns (uint256 water, uint256 hot) {
        (water, hot) = sellForQuote(others, other);
        _sold(hot, water);
        other.bought(others, water);
    }

    function bought(uint256 hot, uint256 water) external onlyLiquid {
        _bought(hot, water);
    }

    function _bought(uint256 hot, uint256 water) private {
        WATER.update(msg.sender, address(this), water);
        _update(address(this), msg.sender, hot);
        emit Bought(this, hot, water);
    }

    function sold(uint256 hot, uint256 water) external onlyLiquid {
        _sold(hot, water);
    }

    function _sold(uint256 hot, uint256 water) private {
        WATER.update(address(this), msg.sender, water);
        _update(msg.sender, address(this), hot);
        emit Sold(this, hot, water);
    }

    function update(address from, address to, uint256 amount) external onlyLiquid {
        _update(from, to, amount);
    }

    function name() public view virtual override returns (string memory) {
        return solid.name();
    }

    function symbol() public view virtual override returns (string memory) {
        return solid.symbol();
    }

    function decimals() public view virtual override returns (uint8) {
        return solid.decimals();
    }

    function predict(IERC20Metadata stuff) public view returns (address future, bytes32 salt) {
        if (address(stuff) == address(0)) {
            revert Nothing();
        }
        salt = bytes32(uint256(uint160(address(stuff))));
        future = Clones.predictDeterministicAddress(address(WATER), salt, address(WATER));
    }

    function make(IERC20Metadata stuff) public returns (Liquid liquid) {
        if (this != WATER) {
            liquid = WATER.make(stuff);
        } else {
            (address future, bytes32 salt) = predict(stuff);
            liquid = Liquid(future);
            if (future.code.length == 0) {
                future = Clones.cloneDeterministic(address(WATER), salt);
                liquid.__initialize(stuff);
                solidOf[future] = stuff;
                emit Made(stuff, liquid);
            }
        }
    }

    function __initialize(IERC20Metadata stuff) public {
        if (address(solid) == address(0)) {
            solid = stuff;
        }
    }

    modifier onlyLiquid() {
        _onlyLiquid();
        _;
    }

    function _onlyLiquid() internal view {
        if (address(WATER.solidOf(msg.sender)) == address(0)) {
            revert Unauthorized();
        }
    }

    event Liquify(Liquid indexed liquid, uint256 hot);
    event Solidify(Liquid indexed liquid, uint256 hot, uint256 cold);
    event Bought(Liquid indexed liquid, uint256 hot, uint256 water);
    event Sold(Liquid indexed liquid, uint256 hot, uint256 water);
    event Made(IERC20Metadata indexed solid, Liquid indexed liquid);

    error Nothing();
    error Drained(Liquid liquid, uint256 pool, uint256 hot);
    error Unauthorized();
}
