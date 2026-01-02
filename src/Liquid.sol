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

    function name() public view virtual override returns (string memory) {
        return substance.name();
    }

    function symbol() public view virtual override returns (string memory) {
        return substance.symbol();
    }

    function decimals() public view virtual override returns (uint8) {
        return substance.decimals();
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

    function liquify(uint256 solids, IERC20Metadata substance_) external {
        Liquid liquid = liquify(substance_);
        liquid.heat(solids);
        liquid.transfer(msg.sender, solids);
    }

    function heats(uint256 solids) public view returns (uint256 pools, uint256 senders) {
        uint256 total = totalSupply() + 2 * solids;
        uint256 pooled = pool() + solids;
        uint256 unpooled = total - pooled;
        pools = 2 * solids * pooled / total;
        senders = 2 * solids * unpooled / total;
    }

    function heat(uint256 solids) external nonReentrant returns (uint256 pools, uint256 senders) {
        substance.safeTransferFrom(msg.sender, address(this), solids);
        (pools, senders) = heats(solids);
        _mint(address(this), pools);
        _mint(msg.sender, senders);
        emit Heat(this, solids);
    }

    function cools(uint256 liquids) public view returns (uint256 solids, uint256 pools, uint256 senders) {
        uint256 total = totalSupply();
        uint256 pooled = pool();
        uint256 unpooled = total - pooled;
        pools = 2 * liquids * pooled / total;
        senders = 2 * liquids * unpooled / total;
        solids = liquids * mass() / unpooled;
    }

    function cool(uint256 liquids) external nonReentrant returns (uint256 solids, uint256 pools, uint256 senders) {
        (solids, pools, senders) = cools(liquids);
        _burn(address(this), pools);
        _burn(msg.sender, senders);
        substance.safeTransfer(msg.sender, solids);
        emit Cool(this, liquids, solids);
    }

    function aways(uint256 liquids, uint256 pooled, uint256 lake_) public pure returns (uint256 water) {
        water = lake_ - pooled * lake_ / (pooled + liquids);
    }

    function aways(uint256 liquids) public view returns (uint256 water) {
        water = aways(liquids, pool(), lake());
    }

    function away(uint256 liquids) external returns (uint256 water) {
        water = aways(liquids);
        _sold(liquids, water);
    }

    function aways(uint256 liquids, Liquid fluid) public view returns (uint256 water, uint256 fluids) {
        water = aways(liquids);
        fluids = fluid.backs(water);
    }

    function away(uint256 liquids, Liquid fluid) external returns (uint256 water, uint256 fluids) {
        (water, fluids) = aways(liquids, fluid);
        _sold(liquids, water);
        fluid.bought(fluids, water);
    }

    function backs(uint256 water) public view returns (uint256 liquids) {
        liquids = aways(water, lake(), pool());
    }

    function back(uint256 water) external returns (uint256 liquids) {
        liquids = backs(water);
        _bought(liquids, water);
    }

    function backs(uint256 fluids, Liquid fluid) public view returns (uint256 water, uint256 liquids) {
        water = backs(fluids);
        liquids = fluid.backs(water);
    }

    function back(uint256 liquids, Liquid fluid) external returns (uint256 water, uint256 fluids) {
        (water, fluids) = backs(liquids, fluid);
        fluid.sold(liquids, water);
        _bought(fluids, water);
    }

    function bought(uint256 liquids, uint256 water) external onlyLiquid {
        _bought(liquids, water);
    }

    function _bought(uint256 liquids, uint256 water) private {
        WATER.update(msg.sender, address(this), water);
        _update(address(this), msg.sender, liquids);
        emit Back(this, liquids, water);
    }

    function sold(uint256 liquids, uint256 water) external onlyLiquid {
        _sold(liquids, water);
    }

    function _sold(uint256 liquids, uint256 water) private {
        WATER.update(address(this), msg.sender, water);
        _update(msg.sender, address(this), liquids);
        emit Away(this, liquids, water);
    }

    function update(address from, address to, uint256 amount) external onlyLiquid {
        _update(from, to, amount);
    }

    function liquified(IERC20Metadata substance_) public view returns (address location, bytes32 salt) {
        if (address(substance_) == address(0)) {
            revert Nothing();
        }
        salt = bytes32(uint256(uint160(address(substance_))));
        location = Clones.predictDeterministicAddress(address(WATER), salt, address(WATER));
    }

    function liquify(IERC20Metadata substance_) public returns (Liquid liquids) {
        if (this != WATER) {
            liquids = WATER.liquify(substance_);
        } else {
            (address location, bytes32 salt) = liquified(substance_);
            liquids = Liquid(location);
            if (location.code.length == 0) {
                location = Clones.cloneDeterministic(address(WATER), salt);
                liquids.__initialize(substance_);
                emit Liquify(substance_, liquids);
            }
        }
    }

    function __initialize(IERC20Metadata substance_) external {
        if (address(substance) == address(0)) {
            substance = substance_;
        }
    }

    modifier onlyLiquid() {
        _onlyLiquid();
        _;
    }

    function _onlyLiquid() private view {
        Liquid liquids = Liquid(msg.sender);
        (address predicted,) = WATER.liquified(liquids.substance());
        if (msg.sender != predicted) {
            revert Unauthorized();
        }
    }

    event Heat(Liquid indexed liquid, uint256 solids);
    event Cool(Liquid indexed liquid, uint256 liquids, uint256 solids);
    event Back(Liquid indexed liquid, uint256 liquids, uint256 water);
    event Away(Liquid indexed liquid, uint256 liquids, uint256 water);
    event Liquify(IERC20Metadata indexed substance, Liquid indexed liquid);

    error Nothing();
    error Unauthorized();
}
