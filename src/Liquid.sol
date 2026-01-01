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

    constructor(IERC20Metadata ice) ERC20("", "") {
        solid = ice;
    }

    function pool() public view returns (uint256) {
        return balanceOf(address(this));
    }

    function lake() public view returns (uint256) {
        return WATER.balanceOf(address(this));
    }

    function mass() public view returns (uint256) {
        return solid.balanceOf(address(this));
    }

    function heat(uint256 cold, IERC20Metadata stuff) external {
        Liquid L = heat(stuff);
        L.heat(cold);
        L.transfer(msg.sender, cold);
    }

    function heat(uint256 cold) external nonReentrant {
        solid.safeTransferFrom(msg.sender, address(this), cold);
        _mint(address(this), cold);
        _mint(msg.sender, cold);
        emit Heat(this, cold);
    }

    function cool(uint256 hot) external nonReentrant returns (uint256 cold) {
        uint256 total = totalSupply();
        uint256 pool_ = pool();
        uint256 held = total - pool_;
        uint256 ours = 2 * hot * pool_ / total;
        uint256 mine = 2 * hot * held / total;
        cold = hot * mass() / held;
        _burn(address(this), ours);
        _burn(msg.sender, mine);
        solid.safeTransfer(msg.sender, cold);
        emit Cool(this, hot, cold);
    }

    function sell(uint256 hot) external returns (uint256 water) {
        water = sells(hot);
        _sold(hot, water);
    }

    function sell(uint256 hot, Liquid L) external returns (uint256 water, uint256 hotter) {
        (water, hotter) = sells(hot, L);
        _sold(hot, water);
        L.bought(hotter, water);
    }

    function buy(uint256 water) external returns (uint256 hot) {
        hot = buys(water);
        _bought(hot, water);
    }

    function buy(uint256 hot, Liquid L) external returns (uint256 water, uint256 hotter) {
        (water, hotter) = buys(hot, L);
        L.sold(hot, water);
        _bought(hotter, water);
    }

    function sells(uint256 hot, uint256 pool_, uint256 lake_) public pure returns (uint256 water) {
        water = lake_ - pool_ * lake_ / (pool_ + hot);
    }

    function sells(uint256 hot) public view returns (uint256 water) {
        water = sells(hot, pool(), lake());
    }

    function sells(uint256 hot, Liquid L) public view returns (uint256 water, uint256 hotter) {
        water = sells(hot);
        hotter = L.buys(water);
    }

    function buys(uint256 water) public view returns (uint256 hot) {
        hot = sells(water, lake(), pool());
    }

    function buys(uint256 hot, Liquid L) public view returns (uint256 water, uint256 hotter) {
        water = buys(hot);
        hotter = L.buys(water);
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

    function heated(IERC20Metadata stuff) public view returns (address future, bytes32 salt) {
        if (address(stuff) == address(0)) {
            revert Nothing();
        }
        salt = bytes32(uint256(uint160(address(stuff))));
        future = Clones.predictDeterministicAddress(address(WATER), salt, address(WATER));
    }

    function heat(IERC20Metadata stuff) public returns (Liquid L) {
        if (this != WATER) {
            L = WATER.heat(stuff);
        } else {
            (address future, bytes32 salt) = heated(stuff);
            L = Liquid(future);
            if (future.code.length == 0) {
                future = Clones.cloneDeterministic(address(WATER), salt);
                L.__initialize(stuff);
                emit Heat(stuff, L);
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
        Liquid L = Liquid(msg.sender);
        (address predicted,) = WATER.heated(L.solid());
        if (msg.sender != predicted) {
            revert Unauthorized();
        }
    }

    event Heat(Liquid indexed L, uint256 hot);
    event Cool(Liquid indexed L, uint256 hot, uint256 cold);
    event Bought(Liquid indexed L, uint256 hot, uint256 water);
    event Sold(Liquid indexed L, uint256 hot, uint256 water);
    event Heat(IERC20Metadata indexed solid, Liquid indexed L);

    error Nothing();
    error Drained(Liquid L, uint256 pool_, uint256 hot);
    error Unauthorized();
}
