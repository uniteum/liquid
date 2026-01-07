// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ISolid} from "isolid/ISolid.sol";
import {ERC20} from "erc20/ERC20.sol";
import {Clones} from "clones/Clones.sol";
import {ReentrancyGuardTransient} from "reentrancy/ReentrancyGuardTransient.sol";

contract Solid is ISolid, ERC20, ReentrancyGuardTransient {
    uint256 constant MOL = 6.02214076e23;
    uint256 constant MOLS = 10000;
    uint256 constant SUPPLY = MOLS * MOL;

    ISolid public immutable NOTHING = this;
    uint256 public immutable MAKER_FEE = 0.001 ether;

    constructor() ERC20("", "") {}

    function pool() public view returns (uint256 solPool, uint256 ethPool) {
        solPool = balanceOf(address(this));
        ethPool = address(this).balance;
    }

    function withdraw(uint256 sol) external nonReentrant returns (uint256 eth) {
        (uint256 solPool, uint256 ethPool) = pool();
        eth = ethPool - ethPool * solPool / (solPool + sol);
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
        sol = solPool - solPool * (ethPool - eth) / ethPool;
        _update(address(this), msg.sender, sol);
        emit Deposit(this, eth, sol);
    }

    receive() external payable {}

    function made(string calldata name, string calldata symbol)
        public
        view
        returns (bool yes, address home, bytes32 salt)
    {
        if (bytes(name).length == 0 || bytes(symbol).length == 0) {
            revert Nothing();
        }
        salt = keccak256(abi.encode(name, symbol));
        home = Clones.predictDeterministicAddress(address(NOTHING), salt, address(NOTHING));
        yes = home.code.length > 0;
    }

    function make(string calldata name, string calldata symbol) external payable returns (ISolid sol) {
        if (this != NOTHING) {
            sol = NOTHING.make{value: msg.value}(name, symbol);
            require(sol.transfer(msg.sender, SUPPLY / 2), "Transfer failed");
        } else {
            if (msg.value < MAKER_FEE) revert PaymentLow(msg.value, MAKER_FEE);
            (bool yes, address home, bytes32 salt) = made(name, symbol);
            if (yes) revert MadeAlready(name, symbol);
            home = Clones.cloneDeterministic(address(NOTHING), salt, 0);
            Solid(payable(home)).zzz_{value: msg.value}(name, symbol, msg.sender);
            sol = ISolid(payable(home));
            emit Make(sol, name, symbol);
        }
    }

    function zzz_(string calldata name, string calldata symbol, address maker) external payable {
        if (bytes(_symbol).length == 0) {
            _name = name;
            _symbol = symbol;
            _mint(address(this), SUPPLY / 2);
            _mint(maker, SUPPLY / 2);
        }
    }
}
