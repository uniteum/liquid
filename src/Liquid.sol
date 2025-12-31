// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.30;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract Liquid is ERC20, ReentrancyGuardTransient {
    using SafeERC20 for IERC20Metadata;

    uint256 public constant WATER_SUPPLY = 1e9 ether;
    uint8 public constant WATER_DECIMALS = 18;
    string public constant WATER_NAME = "Tatar";
    string public constant WATER_SYMBOL = "TATAR";

    Liquid public immutable WATER = this;
    address public immutable WATER_UTILITY = 0xEbCaD83FeAD16e7D18DD691fFD2b39eca56677d8;

    IERC20Metadata public solid = IERC20Metadata(address(0x1CE));

    function melt(uint256 solids) external nonReentrant {
        solid.safeTransferFrom(msg.sender, address(this), solids);
        _mint(address(this), solids);
        _mint(msg.sender, solids);
        emit Melted(this, solids);
    }

    function freeze(uint256 liquids) external nonReentrant returns (uint256 solids) {
        uint256 total = totalSupply();
        uint256 pool = balanceOf(address(this));
        uint256 held = total - pool;
        uint256 ours = 2 * liquids * pool / total;
        uint256 mine = 2 * liquids * held / total;
        solids = liquids * solid.balanceOf(address(this)) / held;
        _burn(address(this), ours);
        _burn(msg.sender, mine);
        solid.safeTransfer(msg.sender, solids);
        emit Frozen(this, liquids, solids);
    }

    function balances() public view returns (uint256 pool, uint256 lake) {
        pool = balanceOf(address(this));
        lake = WATER.balanceOf(address(this));
    }

    function buyQuote(uint256 liquids, uint256 pool, uint256 lake) public view returns (uint256 water) {
        if (pool <= liquids) {
            revert Drained(this, pool, liquids);
        }
        uint256 drained = pool - liquids;
        uint256 filled = pool * lake / drained;
        water = filled - lake;
    }

    function sellQuote(uint256 liquids, uint256 pool, uint256 lake) public pure returns (uint256 water) {
        uint256 filled = pool + liquids;
        uint256 drained = pool * lake / filled;
        water = lake - drained;
    }

    function buyQuote(uint256 liquids) public view returns (uint256 water) {
        (uint256 pool, uint256 lake) = balances();
        water = buyQuote(liquids, pool, lake);
    }

    function sellQuote(uint256 liquids) public view returns (uint256 water) {
        (uint256 pool, uint256 lake) = balances();
        water = sellQuote(liquids, pool, lake);
    }

    function buyQuote(uint256 liquids, Liquid other) public view returns (uint256 water, uint256 others) {
        water = buyQuote(liquids);
        others = other.buyWithQuote(water);
    }

    function sellQuote(uint256 liquids, Liquid other) public view returns (uint256 water, uint256 others) {
        water = sellQuote(liquids);
        others = other.sellForQuote(water);
    }

    function buyWithQuote(uint256 water) public view returns (uint256 liquids) {
        (uint256 pool, uint256 lake) = balances();
        liquids = sellQuote(water, lake, pool);
    }

    function sellForQuote(uint256 water) public view returns (uint256 liquids) {
        (uint256 pool, uint256 lake) = balances();
        water = buyQuote(liquids, lake, pool);
    }

    function buyWithQuote(uint256 others, Liquid other) public view returns (uint256 water, uint256 liquids) {
        water = buyWithQuote(others);
        liquids = other.buyWithQuote(water);
    }

    function sellForQuote(uint256 others, Liquid other) public view returns (uint256 water, uint256 liquids) {
        water = sellForQuote(others);
        liquids = other.sellForQuote(water);
    }

    function buy(uint256 liquids) external returns (uint256 water) {
        water = buyQuote(liquids);
        _bought(liquids, water);
    }

    function sell(uint256 liquids) external returns (uint256 water) {
        water = sellQuote(liquids);
        _sold(liquids, water);
    }

    function buy(uint256 liquids, Liquid other) external returns (uint256 water, uint256 others) {
        (water, others) = buyQuote(liquids, other);
        other.sold(others, water);
        _bought(liquids, water);
    }

    function sell(uint256 liquids, Liquid other) external returns (uint256 water, uint256 others) {
        (water, others) = sellQuote(liquids, other);
        _sold(liquids, water);
        other.bought(others, water);
    }

    function buyWith(uint256 water) external returns (uint256 liquids) {
        liquids = buyWithQuote(water);
        _bought(liquids, water);
    }

    function sellFor(uint256 water) external returns (uint256 liquids) {
        liquids = sellForQuote(water);
        _sold(liquids, water);
    }

    function buyWith(uint256 others, Liquid other) external returns (uint256 water, uint256 liquids) {
        (water, liquids) = buyWithQuote(others, other);
        other.sold(others, water);
        _bought(liquids, water);
    }

    function sellFor(uint256 others, Liquid other) external returns (uint256 water, uint256 liquids) {
        (water, liquids) = sellForQuote(others, other);
        _sold(liquids, water);
        other.bought(others, water);
    }

    function bought(uint256 liquids, uint256 water) external onlyLiquid {
        _bought(liquids, water);
    }

    function _bought(uint256 liquids, uint256 water) private {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(WATER).transfer(address(this), water);
        _transfer(address(this), msg.sender, liquids);
        emit Bought(this, liquids, water);
    }

    function sold(uint256 liquids, uint256 water) external onlyLiquid {
        _sold(liquids, water);
    }

    function _sold(uint256 liquids, uint256 water) private {
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        IERC20(WATER).transferFrom(address(this), msg.sender, water);
        _transfer(msg.sender, address(this), liquids);
        emit Sold(this, liquids, water);
    }

    function name() public view virtual override returns (string memory) {
        return this == WATER ? WATER_NAME : solid.name();
    }

    function symbol() public view virtual override returns (string memory) {
        return this == WATER ? WATER_SYMBOL : solid.symbol();
    }

    function decimals() public view virtual override returns (uint8) {
        return this == WATER ? WATER_DECIMALS : solid.decimals();
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
                emit Made(stuff, liquid);
            }
        }
    }

    function __initialize(IERC20Metadata stuff) public {
        if (address(solid) == address(0)) {
            solid = stuff;
        }
    }

    constructor() ERC20("", "") {
        _mint(WATER_UTILITY, WATER_SUPPLY);
    }

    modifier onlyLiquid() {
        _onlyLiquid();
        _;
    }

    function _onlyLiquid() internal view {
        Liquid liquid = Liquid(msg.sender);
        (address predicted,) = WATER.predict(liquid.solid());
        if (msg.sender != predicted) {
            revert Unauthorized();
        }
    }

    event Melted(Liquid indexed liquid, uint256 liquids);
    event Frozen(Liquid indexed liquid, uint256 liquids, uint256 solids);
    event Bought(Liquid indexed liquid, uint256 liquids, uint256 water);
    event Sold(Liquid indexed liquid, uint256 liquids, uint256 water);
    event Made(IERC20Metadata indexed solid, Liquid indexed liquid);

    error Nothing();
    error Drained(Liquid liquid, uint256 pool, uint256 liquids);
    error Unauthorized();
}
