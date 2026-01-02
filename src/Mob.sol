// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract Mob {
    error NotMember();
    error AlreadyApproved();
    error AlreadyExecuted();
    error BadMessage();
    error CallFailed();

    mapping(address => uint256) public weight;
    uint256 public immutable threshold;

    mapping(bytes32 => uint256) public approvedWeight;
    mapping(bytes32 => mapping(address => bool)) public approvedBy;
    mapping(bytes32 => bool) public executed;

    constructor(address[] memory members, uint256[] memory weights, uint256 _threshold) payable {
        require(members.length == weights.length, "len");
        uint256 sum;
        for (uint256 i = 0; i < members.length; i++) {
            address m = members[i];
            uint256 w = weights[i];
            require(m != address(0) && w != 0, "member");
            require(weight[m] == 0, "dup");
            weight[m] = w;
            sum += w;
        }
        require(_threshold != 0 && _threshold <= sum, "threshold");
        threshold = _threshold;
    }

    receive() external payable {}

    fallback() external payable {
        uint256 w = weight[msg.sender];
        if (w == 0) revert NotMember();

        bytes calldata m = msg.data;
        if (m.length < 20 + 32) revert BadMessage();

        // domain-separated: same raw bytes must match, but not across chains/contracts
        bytes32 h = keccak256(abi.encodePacked(address(this), block.chainid, m));

        if (executed[h]) revert AlreadyExecuted();
        if (approvedBy[h][msg.sender]) revert AlreadyApproved();

        approvedBy[h][msg.sender] = true;
        uint256 total = approvedWeight[h] + w;
        approvedWeight[h] = total;

        if (total >= threshold) {
            _exec(h, m);
        }
    }

    function _exec(bytes32 h, bytes calldata m) private {
        address to;
        uint256 value;

        // to @ [0..20), value @ [20..52)
        assembly {
            to := shr(96, calldataload(m.offset))
            value := calldataload(add(m.offset, 20))
        }

        executed[h] = true;

        bytes calldata data = m[20 + 32:];

        (bool ok,) = to.call{value: value}(data);
        if (!ok) revert CallFailed();
    }
}
