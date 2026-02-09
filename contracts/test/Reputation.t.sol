// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Reputation.sol";

contract ReputationTest is Test {
    Reputation rep;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address judge = makeAddr("judge");

    function setUp() public {
        rep = new Reputation();
        rep.addJudge(judge);
        vm.prank(alice); rep.register();
        vm.prank(bob); rep.register();
    }

    // ─── Register ────────────────────────────────────────────────────
    function test_register() public view { assertEq(rep.totalProfiles(), 2); }
    function test_register_already() public { vm.prank(alice); vm.expectRevert("already registered"); rep.register(); }

    // ─── Endorse ─────────────────────────────────────────────────────
    function test_endorse() public {
        vm.prank(alice); rep.endorse(bob);
        assertEq(rep.getScore(bob), 10);
        (int256 s, uint256 endorsements,,,) = rep.profiles(bob);
        assertEq(s, 10);
        assertEq(endorsements, 1);
    }
    function test_endorse_self() public { vm.prank(alice); vm.expectRevert("self endorse"); rep.endorse(alice); }
    function test_endorse_already() public { vm.prank(alice); rep.endorse(bob); vm.prank(alice); vm.expectRevert("already endorsed"); rep.endorse(bob); }
    function test_endorse_notRegistered() public {
        address charlie = makeAddr("charlie");
        vm.prank(charlie); vm.expectRevert("not registered"); rep.endorse(bob);
    }
    function test_endorse_targetNotRegistered() public {
        address charlie = makeAddr("charlie");
        vm.prank(alice); vm.expectRevert("target not registered"); rep.endorse(charlie);
    }

    // ─── Penalize ────────────────────────────────────────────────────
    function test_penalize() public {
        vm.prank(judge); rep.penalize(alice, 50, "spam");
        assertEq(rep.getScore(alice), -50);
    }
    function test_penalize_notJudge() public { vm.prank(alice); vm.expectRevert("not judge"); rep.penalize(bob, 10, "x"); }
    function test_penalize_notRegistered() public { vm.prank(judge); vm.expectRevert("not registered"); rep.penalize(makeAddr("x"), 10, "x"); }
    function test_penalize_zeroAmount() public { vm.prank(judge); vm.expectRevert("invalid amount"); rep.penalize(alice, 0, "x"); }
    function test_penalize_tooHigh() public { vm.prank(judge); vm.expectRevert("invalid amount"); rep.penalize(alice, 101, "x"); }

    // ─── Score Bounds ────────────────────────────────────────────────
    function test_maxScore() public {
        // Endorse bob 200 times from different users to hit cap
        for (uint256 i; i < 101; i++) {
            address u = address(uint160(1000 + i));
            vm.prank(u); rep.register();
            vm.prank(u); rep.endorse(bob);
        }
        assertEq(rep.getScore(bob), 1000); // capped
    }

    function test_minScore() public {
        for (uint256 i; i < 11; i++) {
            vm.prank(judge); rep.penalize(alice, 100, "bad");
        }
        assertEq(rep.getScore(alice), -1000); // capped
    }

    // ─── Judge Management ────────────────────────────────────────────
    function test_addJudge() public view { assertTrue(rep.isJudge(judge)); }
    function test_addJudge_zero() public { vm.expectRevert("zero address"); rep.addJudge(address(0)); }
    function test_addJudge_already() public { vm.expectRevert("already judge"); rep.addJudge(judge); }
    function test_removeJudge() public { rep.removeJudge(judge); assertFalse(rep.isJudge(judge)); }
    function test_removeJudge_cantRemoveAdmin() public { vm.expectRevert("cant remove admin"); rep.removeJudge(address(this)); }
    function test_removeJudge_notJudge() public { vm.expectRevert("not judge"); rep.removeJudge(alice); }
    function test_addJudge_notAdmin() public { vm.prank(alice); vm.expectRevert("not admin"); rep.addJudge(alice); }

    // ─── Views ───────────────────────────────────────────────────────
    function test_meetsThreshold() public {
        vm.prank(alice); rep.endorse(bob);
        assertTrue(rep.meetsThreshold(bob, 10));
        assertFalse(rep.meetsThreshold(bob, 11));
    }
    function test_meetsThreshold_notRegistered() public view { assertFalse(rep.meetsThreshold(address(0xBEEF), 0)); }
}
