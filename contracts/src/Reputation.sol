// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Reputation — On-chain reputation with endorsements, decay, and slashing
contract Reputation {
    struct Profile {
        uint256 score;
        uint256 endorsements;
        uint256 lastActive;
        bool slashed;
    }

    address public admin;
    uint256 public decayPeriod;  // seconds of inactivity before decay
    uint256 public decayRate;    // points lost per decay period
    uint256 public endorseValue; // points per endorsement

    mapping(address => Profile) public profiles;
    mapping(address => mapping(address => bool)) public hasEndorsed;
    mapping(address => bool) public judges;

    event Endorsed(address indexed from, address indexed to, uint256 newScore);
    event Slashed(address indexed user, uint256 amount, string reason);
    event Restored(address indexed user);
    event ActivityRecorded(address indexed user);

    modifier onlyAdmin() { require(msg.sender == admin, "not admin"); _; }
    modifier onlyJudge() { require(judges[msg.sender] || msg.sender == admin, "not judge"); _; }

    constructor(uint256 _decayPeriod, uint256 _decayRate, uint256 _endorseValue) {
        require(_decayPeriod >= 1 days, "decay too short");
        require(_endorseValue > 0, "zero endorse value");
        admin = msg.sender;
        decayPeriod = _decayPeriod;
        decayRate = _decayRate;
        endorseValue = _endorseValue;
        judges[msg.sender] = true;
    }

    function endorse(address _user) external {
        require(_user != address(0), "zero address");
        require(_user != msg.sender, "self endorse");
        require(!hasEndorsed[msg.sender][_user], "already endorsed");
        require(!profiles[_user].slashed, "user slashed");

        hasEndorsed[msg.sender][_user] = true;
        profiles[_user].endorsements++;
        profiles[_user].score += endorseValue;
        profiles[_user].lastActive = block.timestamp;
        if (profiles[msg.sender].lastActive == 0) profiles[msg.sender].lastActive = block.timestamp;

        emit Endorsed(msg.sender, _user, profiles[_user].score);
    }

    function slash(address _user, uint256 _amount, string calldata _reason) external onlyJudge {
        require(_user != address(0), "zero address");
        require(!profiles[_user].slashed, "already slashed");
        require(bytes(_reason).length > 0, "empty reason");

        Profile storage p = profiles[_user];
        if (_amount >= p.score) { p.score = 0; } else { p.score -= _amount; }
        p.slashed = true;
        emit Slashed(_user, _amount, _reason);
    }

    function restore(address _user) external onlyAdmin {
        require(profiles[_user].slashed, "not slashed");
        profiles[_user].slashed = false;
        emit Restored(_user);
    }

    function recordActivity(address _user) external onlyJudge {
        require(_user != address(0), "zero address");
        profiles[_user].lastActive = block.timestamp;
        emit ActivityRecorded(_user);
    }

    function applyDecay(address _user) external {
        Profile storage p = profiles[_user];
        require(p.score > 0, "no score");
        require(p.lastActive > 0, "no activity");
        require(block.timestamp >= p.lastActive + decayPeriod, "too early");

        uint256 periods = (block.timestamp - p.lastActive) / decayPeriod;
        uint256 totalDecay = periods * decayRate;
        if (totalDecay >= p.score) { p.score = 0; } else { p.score -= totalDecay; }
        p.lastActive = block.timestamp;
    }

    function setJudge(address _judge, bool _active) external onlyAdmin {
        require(_judge != address(0), "zero address");
        judges[_judge] = _active;
    }

    function getScore(address _user) external view returns (uint256) {
        return profiles[_user].score;
    }

    function getProfile(address _user) external view returns (uint256 score, uint256 endorsements, uint256 lastActive, bool slashed) {
        Profile storage p = profiles[_user];
        return (p.score, p.endorsements, p.lastActive, p.slashed);
    }
}
