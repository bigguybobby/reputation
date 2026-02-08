// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Reputation.sol";

contract ReputationTest is Test {
    Reputation rep;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address judge = makeAddr("judge");
    address admin;

    function setUp() public {
        vm.warp(10000);
        admin = address(this);
        rep = new Reputation(30 days, 10, 50); // 30d decay, 10pts/period, 50pts/endorse
        rep.setJudge(judge, true);
    }

    // ─── Constructor ─────────────────────────────────────────────────
    function test_constructor() public view {
        assertEq(rep.endorseValue(), 50);
        assertEq(rep.decayRate(), 10);
    }
    function test_constructor_decayTooShort() public { vm.expectRevert("decay too short"); new Reputation(1 hours, 10, 50); }
    function test_constructor_zeroEndorse() public { vm.expectRevert("zero endorse value"); new Reputation(30 days, 10, 0); }

    // ─── Endorse ─────────────────────────────────────────────────────
    function test_endorse() public {
        vm.prank(alice);
        rep.endorse(bob);
        assertEq(rep.getScore(bob), 50);
    }

    function test_endorse_selfEndorse() public { vm.prank(alice); vm.expectRevert("self endorse"); rep.endorse(alice); }
    function test_endorse_zeroAddr() public { vm.prank(alice); vm.expectRevert("zero address"); rep.endorse(address(0)); }
    function test_endorse_already() public { vm.prank(alice); rep.endorse(bob); vm.prank(alice); vm.expectRevert("already endorsed"); rep.endorse(bob); }

    function test_endorse_slashed() public {
        vm.prank(alice); rep.endorse(bob);
        vm.prank(judge); rep.slash(bob, 100, "bad");
        vm.prank(makeAddr("c")); vm.expectRevert("user slashed"); rep.endorse(bob);
    }

    function test_endorse_multiple() public {
        vm.prank(alice); rep.endorse(bob);
        vm.prank(makeAddr("c")); rep.endorse(bob);
        assertEq(rep.getScore(bob), 100);
    }

    // ─── Slash ───────────────────────────────────────────────────────
    function test_slash() public {
        vm.prank(alice); rep.endorse(bob);
        vm.prank(judge);
        rep.slash(bob, 30, "spam");
        assertEq(rep.getScore(bob), 20);
    }

    function test_slash_fullDrain() public {
        vm.prank(alice); rep.endorse(bob);
        vm.prank(judge); rep.slash(bob, 999, "nuke");
        assertEq(rep.getScore(bob), 0);
    }

    function test_slash_notJudge() public { vm.prank(alice); vm.expectRevert("not judge"); rep.slash(bob, 10, "x"); }
    function test_slash_alreadySlashed() public {
        vm.prank(alice); rep.endorse(bob);
        vm.prank(judge); rep.slash(bob, 10, "x");
        vm.prank(judge); vm.expectRevert("already slashed"); rep.slash(bob, 10, "y");
    }
    function test_slash_emptyReason() public { vm.prank(judge); vm.expectRevert("empty reason"); rep.slash(bob, 10, ""); }

    // ─── Restore ─────────────────────────────────────────────────────
    function test_restore() public {
        vm.prank(alice); rep.endorse(bob);
        vm.prank(judge); rep.slash(bob, 10, "x");
        rep.restore(bob);
        (,,, bool slashed) = rep.getProfile(bob);
        assertFalse(slashed);
    }

    function test_restore_notSlashed() public { vm.expectRevert("not slashed"); rep.restore(bob); }

    // ─── Decay ───────────────────────────────────────────────────────
    function test_applyDecay() public {
        vm.prank(alice); rep.endorse(bob); // 50 pts
        vm.warp(block.timestamp + 60 days); // 2 periods
        rep.applyDecay(bob);
        assertEq(rep.getScore(bob), 30); // 50 - 2*10
    }

    function test_decay_tooEarly() public {
        vm.prank(alice); rep.endorse(bob);
        vm.expectRevert("too early"); rep.applyDecay(bob);
    }

    function test_decay_noScore() public { vm.expectRevert("no score"); rep.applyDecay(bob); }

    function test_decay_fullDrain() public {
        vm.prank(alice); rep.endorse(bob); // 50 pts
        vm.warp(block.timestamp + 180 days); // 6 periods = 60 > 50
        rep.applyDecay(bob);
        assertEq(rep.getScore(bob), 0);
    }

    // ─── Admin ───────────────────────────────────────────────────────
    function test_setJudge() public {
        rep.setJudge(alice, true);
        assertTrue(rep.judges(alice));
    }

    function test_setJudge_zero() public { vm.expectRevert("zero address"); rep.setJudge(address(0), true); }

    function test_recordActivity() public {
        vm.prank(judge);
        rep.recordActivity(bob);
        (,, uint256 lastActive,) = rep.getProfile(bob);
        assertEq(lastActive, block.timestamp);
    }

    // ─── Views ───────────────────────────────────────────────────────
    function test_getProfile() public {
        vm.prank(alice); rep.endorse(bob);
        (uint256 score, uint256 endorsements,,) = rep.getProfile(bob);
        assertEq(score, 50);
        assertEq(endorsements, 1);
    }
}
