// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Reputation — On-chain reputation with endorsements & penalties
contract Reputation {
    struct Profile {
        int256 score;
        uint256 endorsements;
        uint256 penalties;
        uint256 lastUpdate;
        bool exists;
    }

    address public admin;
    mapping(address => bool) public isJudge;
    mapping(address => Profile) public profiles;
    mapping(address => mapping(address => bool)) public hasEndorsed;
    uint256 public totalProfiles;
    int256 public constant MAX_SCORE = 1000;
    int256 public constant MIN_SCORE = -1000;

    event Registered(address indexed user);
    event Endorsed(address indexed from, address indexed to);
    event Penalized(address indexed user, uint256 amount, string reason);
    event JudgeAdded(address indexed judge);
    event JudgeRemoved(address indexed judge);
    event ScoreAdjusted(address indexed user, int256 newScore);

    modifier onlyAdmin() { require(msg.sender == admin, "not admin"); _; }
    modifier onlyJudge() { require(isJudge[msg.sender], "not judge"); _; }

    constructor() {
        admin = msg.sender;
        isJudge[msg.sender] = true;
    }

    function register() external {
        require(!profiles[msg.sender].exists, "already registered");
        profiles[msg.sender] = Profile(0, 0, 0, block.timestamp, true);
        totalProfiles++;
        emit Registered(msg.sender);
    }

    function endorse(address _user) external {
        require(profiles[msg.sender].exists, "not registered");
        require(profiles[_user].exists, "target not registered");
        require(msg.sender != _user, "self endorse");
        require(!hasEndorsed[msg.sender][_user], "already endorsed");

        hasEndorsed[msg.sender][_user] = true;
        profiles[_user].endorsements++;
        _adjustScore(_user, 10);
        emit Endorsed(msg.sender, _user);
    }

    function penalize(address _user, uint256 _amount, string calldata _reason) external onlyJudge {
        require(profiles[_user].exists, "not registered");
        require(_amount > 0 && _amount <= 100, "invalid amount");

        profiles[_user].penalties++;
        _adjustScore(_user, -int256(_amount));
        emit Penalized(_user, _amount, _reason);
    }

    function addJudge(address _j) external onlyAdmin {
        require(_j != address(0), "zero address");
        require(!isJudge[_j], "already judge");
        isJudge[_j] = true;
        emit JudgeAdded(_j);
    }

    function removeJudge(address _j) external onlyAdmin {
        require(isJudge[_j], "not judge");
        require(_j != admin, "cant remove admin");
        isJudge[_j] = false;
        emit JudgeRemoved(_j);
    }

    function getScore(address _user) external view returns (int256) {
        return profiles[_user].score;
    }

    function meetsThreshold(address _user, int256 _min) external view returns (bool) {
        return profiles[_user].exists && profiles[_user].score >= _min;
    }

    function _adjustScore(address _user, int256 _delta) internal {
        int256 s = profiles[_user].score + _delta;
        if (s > MAX_SCORE) s = MAX_SCORE;
        if (s < MIN_SCORE) s = MIN_SCORE;
        profiles[_user].score = s;
        profiles[_user].lastUpdate = block.timestamp;
        emit ScoreAdjusted(_user, s);
    }
}
