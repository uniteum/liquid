// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.30;

import {ERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract Liquid is ERC20, ReentrancyGuardTransient {
    using SafeERC20 for IERC20Metadata;

    Liquid public immutable WATER = this;

    IERC20Metadata public substance;

    constructor(IERC20Metadata ice) ERC20("", "") {
        substance = ice;
    }

    function pool() public view returns (uint256) {
        return balanceOf(address(this));
    }

    function lake() public view returns (uint256) {
        return WATER.balanceOf(address(this));
    }

    function mass() public view returns (uint256) {
        return substance.balanceOf(address(this));
    }

    function liquify(uint256 solid, IERC20Metadata stuff) external {
        Liquid L = liquify(stuff);
        L.heat(solid);
        L.transfer(msg.sender, solid);
    }

    function heat(uint256 solid) external nonReentrant {
        substance.safeTransferFrom(msg.sender, address(this), solid);
        _mint(address(this), solid);
        _mint(msg.sender, solid);
        emit Heat(this, solid);
    }

    function cool(uint256 liquid) external nonReentrant returns (uint256 solid) {
        uint256 total = totalSupply();
        uint256 pool_ = pool();
        uint256 held = total - pool_;
        uint256 ours = 2 * liquid * pool_ / total;
        uint256 mine = 2 * liquid * held / total;
        solid = liquid * mass() / held;
        _burn(address(this), ours);
        _burn(msg.sender, mine);
        substance.safeTransfer(msg.sender, solid);
        emit Cool(this, liquid, solid);
    }

    function sell(uint256 liquid) external returns (uint256 water) {
        water = sells(liquid);
        _sold(liquid, water);
    }

    function sell(uint256 liquid, Liquid L) external returns (uint256 water, uint256 other) {
        (water, other) = sells(liquid, L);
        _sold(liquid, water);
        L.bought(other, water);
    }

    function buy(uint256 water) external returns (uint256 liquid) {
        liquid = buys(water);
        _bought(liquid, water);
    }

    function buy(uint256 liquid, Liquid L) external returns (uint256 water, uint256 other) {
        (water, other) = buys(liquid, L);
        L.sold(liquid, water);
        _bought(other, water);
    }

    function sells(uint256 liquid, uint256 pool_, uint256 lake_) public pure returns (uint256 water) {
        water = lake_ - pool_ * lake_ / (pool_ + liquid);
    }

    function sells(uint256 liquid) public view returns (uint256 water) {
        water = sells(liquid, pool(), lake());
    }

    function sells(uint256 liquid, Liquid L) public view returns (uint256 water, uint256 other) {
        water = sells(liquid);
        other = L.buys(water);
    }

    function buys(uint256 water) public view returns (uint256 liquid) {
        liquid = sells(water, lake(), pool());
    }

    function buys(uint256 other, Liquid L) public view returns (uint256 water, uint256 liquid) {
        water = buys(other);
        liquid = L.buys(water);
    }

    function bought(uint256 liquid, uint256 water) external onlyLiquid {
        _bought(liquid, water);
    }

    function _bought(uint256 liquid, uint256 water) private {
        WATER.update(msg.sender, address(this), water);
        _update(address(this), msg.sender, liquid);
        emit Bought(this, liquid, water);
    }

    function sold(uint256 liquid, uint256 water) external onlyLiquid {
        _sold(liquid, water);
    }

    function _sold(uint256 liquid, uint256 water) private {
        WATER.update(address(this), msg.sender, water);
        _update(msg.sender, address(this), liquid);
        emit Sold(this, liquid, water);
    }

    function update(address from, address to, uint256 amount) external onlyLiquid {
        _update(from, to, amount);
    }

    function name() public view virtual override returns (string memory) {
        return substance.name();
    }

    function symbol() public view virtual override returns (string memory) {
        return substance.symbol();
    }

    function decimals() public view virtual override returns (uint8) {
        return substance.decimals();
    }

    function liquified(IERC20Metadata stuff) public view returns (address future, bytes32 salt) {
        if (address(stuff) == address(0)) {
            revert Nothing();
        }
        salt = bytes32(uint256(uint160(address(stuff))));
        future = Clones.predictDeterministicAddress(address(WATER), salt, address(WATER));
    }

    function liquify(IERC20Metadata stuff) public returns (Liquid L) {
        if (this != WATER) {
            L = WATER.liquify(stuff);
        } else {
            (address future, bytes32 salt) = liquified(stuff);
            L = Liquid(future);
            if (future.code.length == 0) {
                future = Clones.cloneDeterministic(address(WATER), salt);
                L.__initialize(stuff);
                emit Liquified(stuff, L);
            }
        }
    }

    function __initialize(IERC20Metadata stuff) public {
        if (address(substance) == address(0)) {
            substance = stuff;
        }
    }

    modifier onlyLiquid() {
        _onlyLiquid();
        _;
    }

    function _onlyLiquid() internal view {
        Liquid L = Liquid(msg.sender);
        (address predicted,) = WATER.liquified(L.substance());
        if (msg.sender != predicted) {
            revert Unauthorized();
        }
    }

    event Heat(Liquid indexed L, uint256 solid);
    event Cool(Liquid indexed L, uint256 liquid, uint256 solid);
    event Bought(Liquid indexed L, uint256 liquid, uint256 water);
    event Sold(Liquid indexed L, uint256 liquid, uint256 water);
    event Liquified(IERC20Metadata indexed substance, Liquid indexed L);

    error Nothing();
    error Unauthorized();
}
