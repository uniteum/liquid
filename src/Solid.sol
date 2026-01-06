// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {ERC20} from "erc20/ERC20.sol";
import {Clones} from "clones/Clones.sol";
import {ReentrancyGuardTransient} from "reentrancy/ReentrancyGuardTransient.sol";

contract Solid is ERC20, ReentrancyGuardTransient {
    uint256 public constant MOLE = 6.02214076e23;
    uint256 public constant SUPPLY = 1000 * MOLE;
    Solid public immutable NOTHING = this;

    constructor() ERC20("", "") {}

    function pool() public view returns (uint256 solids, uint256 eth) {
        solids = balanceOf(address(this));
        eth = address(this).balance;
    }

    function withdraw(uint256 here) external nonReentrant returns (uint256 there) {
        (uint256 far, uint256 near) = pool();
        there = far - near * far / (near + here);
        _update(msg.sender, address(this), there);

        emit Withdraw(this, here, there);

        (bool ok, bytes memory returnData) = msg.sender.call{value: there}("");
        if (!ok) {
            if (returnData.length > 0) {
                assembly {
                    revert(add(returnData, 32), mload(returnData))
                }
            } else {
                revert WithdrawFailed();
            }
        }
    }

    function deposit() public payable returns (uint256 there) {
        (uint256 far, uint256 near) = pool();
        uint256 here = msg.value;
        near -= here;
        there = far - near * far / (near + here);
        _update(address(this), msg.sender, there);
        emit Deposit(this, here, there);
    }

    receive() external payable {
        deposit();
    }

    function made(string calldata n, string calldata s) public view returns (address location, bytes32 salt) {
        if (bytes(n).length == 0 || bytes(s).length == 0) {
            revert Nothing();
        }
        salt = keccak256(abi.encode(n, s));
        location = Clones.predictDeterministicAddress(address(NOTHING), salt, address(NOTHING));
    }

    function make(string calldata n, string calldata s) external returns (Solid solids) {
        if (this != NOTHING) {
            solids = NOTHING.make(n, s);
        } else {
            (address location, bytes32 salt) = made(n, s);
            solids = Solid(payable(location));
            if (location.code.length == 0) {
                location = Clones.cloneDeterministic(address(NOTHING), salt, 0);
                solids.zzz_(n, s);
                emit Make(this, n, s);
            }
        }
    }

    function zzz_(string calldata n, string calldata s) external {
        if (bytes(_symbol).length == 0) {
            _name = n;
            _symbol = s;
            _mint(address(this), SUPPLY);
        }
    }

    event Make(Solid indexed solid, string indexed name, string indexed symbol);
    event Deposit(Solid indexed solid, uint256 solids, uint256 eth);
    event Withdraw(Solid indexed solid, uint256 solids, uint256 eth);

    error Nothing();
    error WithdrawFailed();
}
