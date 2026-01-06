// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {ERC20} from "erc20/ERC20.sol";
import {Clones} from "clones/Clones.sol";
import {ReentrancyGuardTransient} from "reentrancy/ReentrancyGuardTransient.sol";

contract Solid is ERC20, ReentrancyGuardTransient {
    uint256 public constant MOLE = 6.02214076e23;
    uint256 constant MOLES = 10000;
    uint256 constant SUPPLY = MOLES * MOLE;
    Solid public immutable NOTHING = this;

    constructor() ERC20("", "") {}

    function pool() public view returns (uint256 solPool, uint256 ethPool) {
        solPool = balanceOf(address(this));
        ethPool = address(this).balance;
    }

    function withdraw(uint256 sol) external nonReentrant returns (uint256 eth) {
        (uint256 solPool, uint256 ethPool) = pool();
        eth = ethPool - solPool * ethPool / (solPool + sol);
        _update(msg.sender, address(this), sol);
        emit Withdraw(this, sol, eth);
        (bool ok, bytes memory returnData) = msg.sender.call{value: eth}("");
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

    function deposit() public payable returns (uint256 sol) {
        (uint256 solPool, uint256 ethPool) = pool();
        uint256 eth = msg.value;
        sol = solPool - (ethPool - eth) * solPool / ethPool;
        _update(address(this), msg.sender, sol);
        emit Deposit(this, eth, sol);
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

    function make(string calldata n, string calldata s) external returns (Solid sol) {
        if (this != NOTHING) {
            sol = NOTHING.make(n, s);
        } else {
            (address location, bytes32 salt) = made(n, s);
            sol = Solid(payable(location));
            if (location.code.length == 0) {
                location = Clones.cloneDeterministic(address(NOTHING), salt, 0);
                sol.zzz_(n, s);
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
    event Deposit(Solid indexed solid, uint256 sol, uint256 eth);
    event Withdraw(Solid indexed solid, uint256 sol, uint256 eth);

    error Nothing();
    error WithdrawFailed();
}
