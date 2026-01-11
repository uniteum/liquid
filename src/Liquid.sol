// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.30;

import {ERC20, IERC20Metadata} from "erc20/ERC20.sol";
import {SafeERC20} from "erc20/SafeERC20.sol";
import {Clones} from "clones/Clones.sol";
import {ReentrancyGuardTransient} from "reentrancy/ReentrancyGuardTransient.sol";

contract Liquid is ERC20, ReentrancyGuardTransient {
    using SafeERC20 for IERC20Metadata;

    Liquid public immutable HUB = this;

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
        return HUB.balanceOf(address(this));
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

    function cools(uint256 spokes) public view returns (uint256 solids, uint256 pools, uint256 senders) {
        uint256 total = totalSupply();
        uint256 pooled = pool();
        uint256 unpooled = total - pooled;
        pools = 2 * spokes * pooled / total;
        senders = 2 * spokes * unpooled / total;
        solids = spokes * mass() / unpooled;
    }

    function cool(uint256 spokes) external nonReentrant returns (uint256 solids, uint256 pools, uint256 senders) {
        (solids, pools, senders) = cools(spokes);
        _burn(address(this), pools);
        _burn(msg.sender, senders);
        solid.safeTransfer(msg.sender, solids);
        emit Cool(this, spokes, solids);
    }

    function aways(uint256 here, uint256 near, uint256 far) public pure returns (uint256 there) {
        there = far - near * far / (near + here);
    }

    function aways(uint256 spokes) public view returns (uint256 hubs) {
        hubs = aways(spokes, pool(), lake());
    }

    function away(uint256 spokes) external returns (uint256 hubs) {
        hubs = aways(spokes);
        _went(spokes, hubs);
    }

    function aways(uint256 spokes, Liquid fluid) public view returns (uint256 hubs, uint256 fluids) {
        hubs = aways(spokes);
        fluids = fluid.backs(hubs);
    }

    function away(uint256 spokes, Liquid fluid) external returns (uint256 hubs, uint256 fluids) {
        (hubs, fluids) = aways(spokes, fluid);
        _went(spokes, hubs);
        fluid.came(fluids, hubs);
    }

    function backs(uint256 hubs) public view returns (uint256 spokes) {
        spokes = aways(hubs, lake(), pool());
    }

    function back(uint256 hubs) external returns (uint256 spokes) {
        spokes = backs(hubs);
        _came(spokes, hubs);
    }

    function backs(uint256 fluids, Liquid fluid) public view returns (uint256 hubs, uint256 spokes) {
        hubs = backs(fluids);
        spokes = fluid.backs(hubs);
    }

    function back(uint256 fluids, Liquid fluid) external returns (uint256 hubs, uint256 spokes) {
        (hubs, spokes) = backs(fluids, fluid);
        fluid.went(spokes, hubs);
        _came(fluids, hubs);
    }

    function came(uint256 spokes, uint256 hubs) external onlyLiquid {
        _came(spokes, hubs);
    }

    function _came(uint256 spokes, uint256 hubs) private {
        HUB.update(msg.sender, address(this), hubs);
        _update(address(this), msg.sender, spokes);
        emit Back(this, spokes, hubs);
    }

    function went(uint256 spokes, uint256 hubs) external onlyLiquid {
        _went(spokes, hubs);
    }

    function _went(uint256 spokes, uint256 hubs) private {
        HUB.update(address(this), msg.sender, hubs);
        _update(msg.sender, address(this), spokes);
        emit Away(this, spokes, hubs);
    }

    function update(address from, address to, uint256 amount) external onlyLiquid {
        _update(from, to, amount);
    }

    function made(IERC20Metadata solid_) public view returns (bool yes, address home, bytes32 salt) {
        if (address(solid_) == address(0)) {
            revert Nothing();
        }
        salt = bytes32(uint256(uint160(address(solid_))));
        home = Clones.predictDeterministicAddress(address(HUB), salt, address(HUB));
        yes = home.code.length != 0;
    }

    function make(IERC20Metadata solid_) public returns (Liquid spokes) {
        if (this != HUB) {
            spokes = HUB.make(solid_);
        } else {
            (bool yes, address home, bytes32 salt) = made(solid_);
            spokes = Liquid(home);
            if (!yes) {
                home = Clones.cloneDeterministic(address(HUB), salt, 0);
                emit Wrap(spokes, solid_);
                spokes.zzz_(solid_);
            }
        }
    }

    function zzz_(IERC20Metadata solid_) external {
        if (address(solid) == address(0)) {
            solid = solid_;
        }
    }

    modifier onlyLiquid() {
        _onlyLiquid();
        _;
    }

    function _onlyLiquid() private view {
        (, address home,) = HUB.made(Liquid(msg.sender).solid());
        if (msg.sender != home) {
            revert Unauthorized();
        }
    }

    event Heat(Liquid indexed liquid, uint256 solids);
    event Cool(Liquid indexed liquid, uint256 spokes, uint256 solids);
    event Back(Liquid indexed liquid, uint256 spokes, uint256 hubs);
    event Away(Liquid indexed liquid, uint256 spokes, uint256 hubs);
    event Wrap(Liquid indexed liquid, IERC20Metadata indexed solid);

    error Nothing();
    error Unauthorized();
}
