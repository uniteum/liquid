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

    function name() public view virtual override returns (string memory) {
        return solid.name();
    }

    function symbol() public view virtual override returns (string memory) {
        return solid.symbol();
    }

    function decimals() public view virtual override returns (uint8) {
        return solid.decimals();
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

    function heats(uint256 solids) public view returns (uint256 pools, uint256 senders) {
        uint256 total = totalSupply() + 2 * solids;
        uint256 pooled = pool() + solids;
        uint256 unpooled = total - pooled;
        pools = 2 * solids * pooled / total;
        senders = 2 * solids * unpooled / total;
    }

    function heat(uint256 solids) external nonReentrant returns (uint256 pools, uint256 senders) {
        solid.safeTransferFrom(msg.sender, address(this), solids);
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
        solid.safeTransfer(msg.sender, solids);
        emit Cool(this, liquids, solids);
    }

    function aways(uint256 here, uint256 near, uint256 far) public pure returns (uint256 there) {
        there = far - near * far / (near + here);
    }

    function aways(uint256 liquids) public view returns (uint256 water) {
        water = aways(liquids, pool(), lake());
    }

    function away(uint256 liquids) external returns (uint256 water) {
        water = aways(liquids);
        _went(liquids, water);
    }

    function aways(uint256 liquids, Liquid fluid) public view returns (uint256 water, uint256 fluids) {
        water = aways(liquids);
        fluids = fluid.backs(water);
    }

    function away(uint256 liquids, Liquid fluid) external returns (uint256 water, uint256 fluids) {
        (water, fluids) = aways(liquids, fluid);
        _went(liquids, water);
        fluid.came(fluids, water);
    }

    function backs(uint256 water) public view returns (uint256 liquids) {
        liquids = aways(water, lake(), pool());
    }

    function back(uint256 water) external returns (uint256 liquids) {
        liquids = backs(water);
        _came(liquids, water);
    }

    function backs(uint256 fluids, Liquid fluid) public view returns (uint256 water, uint256 liquids) {
        water = backs(fluids);
        liquids = fluid.backs(water);
    }

    function back(uint256 fluids, Liquid fluid) external returns (uint256 water, uint256 liquids) {
        (water, liquids) = backs(fluids, fluid);
        fluid.went(liquids, water);
        _came(fluids, water);
    }

    function came(uint256 liquids, uint256 water) external onlyLiquid {
        _came(liquids, water);
    }

    function _came(uint256 liquids, uint256 water) private {
        WATER.update(msg.sender, address(this), water);
        _update(address(this), msg.sender, liquids);
        emit Back(this, liquids, water);
    }

    function went(uint256 liquids, uint256 water) external onlyLiquid {
        _went(liquids, water);
    }

    function _went(uint256 liquids, uint256 water) private {
        WATER.update(address(this), msg.sender, water);
        _update(msg.sender, address(this), liquids);
        emit Away(this, liquids, water);
    }

    function update(address from, address to, uint256 amount) external onlyLiquid {
        _update(from, to, amount);
    }

    function made(IERC20Metadata solid_) public view returns (address location, bytes32 salt) {
        if (address(solid_) == address(0)) {
            revert Nothing();
        }
        salt = bytes32(uint256(uint160(address(solid_))));
        location = Clones.predictDeterministicAddress(address(WATER), salt, address(WATER));
    }

    function make(IERC20Metadata solid_) public returns (Liquid liquids) {
        if (this != WATER) {
            liquids = WATER.make(solid_);
        } else {
            (address location, bytes32 salt) = made(solid_);
            liquids = Liquid(location);
            if (location.code.length == 0) {
                location = Clones.cloneDeterministic(address(WATER), salt);
                liquids.__initialize(solid_);
                emit Wrap(liquids, solid_);
            }
        }
    }

    function __initialize(IERC20Metadata solid_) external {
        if (address(solid) == address(0)) {
            solid = solid_;
        }
    }

    modifier onlyLiquid() {
        _onlyLiquid();
        _;
    }

    function _onlyLiquid() private view {
        (address location,) = WATER.made(Liquid(msg.sender).solid());
        if (msg.sender != location) {
            revert Unauthorized();
        }
    }

    event Heat(Liquid indexed liquid, uint256 solids);
    event Cool(Liquid indexed liquid, uint256 liquids, uint256 solids);
    event Back(Liquid indexed liquid, uint256 liquids, uint256 water);
    event Away(Liquid indexed liquid, uint256 liquids, uint256 water);
    event Wrap(Liquid indexed liquid, IERC20Metadata indexed solid);

    error Nothing();
    error Unauthorized();
}
