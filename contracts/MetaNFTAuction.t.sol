// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {MetaNFTAuction} from "./MetaNFTAuction.sol";
import {MetaNFT} from "./MetaNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// forge test --match-contract MetaNFTAuction --fork-url url -vvv

contract MetaNFTAuctionTest is Test {
    MetaNFTAuction private auction;
    MetaNFT private nft;

    // NFT市场管理员
    address private admin = address(0xA11CE);
    address private proxyAdmin = address(0xBEEF);
    address private constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function setUp() public {
        MetaNFTAuction impl = new MetaNFTAuction();
        bytes memory initData = abi.encodeCall(MetaNFTAuction.initialize, (admin));
        // 创建NFT市场代理合约
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(impl), proxyAdmin, initData);

        auction = MetaNFTAuction(address(proxy));
        nft = new MetaNFT();
    }

    function test_getVersion() public view {
        assertEq(auction.getVersion(), "MetaNFTAuctionV1");
    }

    function test_getPriceInDollar() public view {
        // 获取eth兑换美元的原始价格
        uint256 ethPrice = auction.getPriceInDollar(1);
        // 获取usdc兑换美元的原始价格
        uint256 usdcPrice = auction.getPriceInDollar(2);
        console2.log("ETH/USD price", ethPrice);
        console2.log("USDC/USD price", usdcPrice);
        assertGt(ethPrice, 0);
        assertGt(usdcPrice, 0);
    }

    function test_initializeOnlyOnce() public {
        // 后续所有合约调用都通过admin地址身份发起
        vm.startPrank(admin);
        // 下一次合约调用必须触发回滚，且回滚的错误信息必须与指定字符串完全一致
        vm.expectRevert("Initializable: contract is already initialized");
        auction.initialize(admin);
    }

    function test_startOnlyAdmin() public {
        // 卖家地址
        address seller = address(0xB0B);
        // 后续合约已卖家身份发起
        vm.startPrank(seller);
        // 下一个合约触发回滚
        vm.expectRevert("not admin");
        IERC20 usdc = IERC20(USDC_SEPOLIA);
        // 只有NFT市场管理员身份才能调用
        auction.start(seller, 1, address(nft), 1000, 3600, address(usdc));
    }

    function test_startIncrementsAuctionId() public {
        IERC20 usdc = IERC20(USDC_SEPOLIA);
        address seller = address(0xB0B);
        vm.startPrank(admin);
        // 卖家发起拍卖
        auction.start(seller, 1, address(nft), 1000, 3600, address(usdc));
        assertEq(auction.auctionId(), 1);
        auction.start(seller, 1, address(nft), 1000, 3600, address(usdc));
        assertEq(auction.auctionId(), 2);
    }

    // 测试超过了拍卖时间
    function test_startAuctionGtDuration() public {
        IERC20 usdc = IERC20(USDC_SEPOLIA);
        address seller = address(0xB0B);
        vm.startPrank(admin);
        auction.start(seller, 1, address(nft), 1000, 30, address(usdc));
        uint256 currentAuctionId = auction.auctionId() - 1;
        (,,,, uint256 startTime,,, uint256 duration,,,) = auction.auctions(currentAuctionId);

        // 给卖家充值1eth
        vm.deal(seller, 1 ether);
        // 快进区块时间50s
        vm.warp(block.timestamp + 50);
        console2.log("current time", block.timestamp);
        console2.log("startTime", startTime);
        console2.log("duration", duration);
        //require(block.timestamp < startTime + duration, "my require");
        vm.expectRevert("ended");
        vm.startPrank(seller);
        auction.bid{value: 1 ether}(currentAuctionId);
    }

    // 测试起拍价太少
    function test_lowStartingPrice() public {
        IERC20 usdc = IERC20(USDC_SEPOLIA);
        address seller = address(0xB0B);
        // 1eth兑换的美元价格
        uint256 ethPrice = auction.getPriceInDollar(1) / 10 ** 8;
        console2.log("test_lowStartingPrice ethPrice", ethPrice, auction.getPriceInDollar(1));
        vm.startPrank(admin);
        // 由管理员发起，卖家上架NFT，起始价为eth兑换价+1
        auction.start(seller, 1, address(nft), ethPrice + 1, 3600, address(usdc));
        uint256 currentAuctionId = auction.auctionId() - 1;
        //usdc.approve(address(auction), 0);
        // 给卖家充值1eth
        vm.deal(seller, 1 ether);
        //vm.warp(block.timestamp + 50);
        vm.expectRevert("invalid startingPrice");
        vm.startPrank(seller);
        // 卖家以1eth出价，因为价格低于起拍价，所以异常
        auction.bid{value: 1 ether}(currentAuctionId);
    }

    // 测试修改支付方式
    function test_changeBidMethod() public {
        IERC20 usdc = IERC20(USDC_SEPOLIA);
        address seller = address(0xB0B);
        address bidder = address(0xB0123);
        // 1eth兑换的美元
        uint256 ethPrice = auction.getPriceInDollar(1) / 10 ** 8;
        console2.log("test_lowStartingPrice ethPrice", ethPrice, auction.getPriceInDollar(1));
        vm.startPrank(admin);
        // 卖家发起拍卖，起拍价为1eth
        auction.start(seller, 1, address(nft), ethPrice, 3600, address(usdc));
        uint256 currentAuctionId = auction.auctionId() - 1;
        //usdc.approve(address(auction), 0);
        // 给卖家充值2eth
        vm.deal(seller, 2 ether);
        // 给买家充值2eth
        vm.deal(bidder, 2 ether);
        //vm.warp(block.timestamp + 50);
        vm.startPrank(bidder);
        // 买家出价2eth
        auction.bid{value: 2 ether}(currentAuctionId);
        // 第二次低价起拍
        // 给买家充值10usdc
        deal(address(usdc), bidder, 10e6);
        // 买家授权NFT合约10usdc额度
        usdc.approve(address(auction), 10e6);
        console2.log(
            "test_changeBidMethod usdc balance", usdc.balanceOf(bidder), usdc.allowance(bidder, address(auction))
        );
        vm.expectRevert("invalid method");
        // 同一买家，同一NFT，只能以同一种支付方式支付
        auction.bid(currentAuctionId);
    }

    //测试低于上一次最高价
    function test_bidLowerThanHighestBid() public {
        IERC20 usdc = IERC20(USDC_SEPOLIA);
        address seller = address(0xB0B);
        address bidder = address(0xB0123);
        uint256 ethPrice = auction.getPriceInDollar(1) / 10 ** 8;
        console2.log("test_lowStartingPrice ethPrice", ethPrice, auction.getPriceInDollar(1));
        vm.prank(admin);
        auction.start(seller, 1, address(nft), ethPrice, 3600, address(usdc));
        uint256 currentAuctionId = auction.auctionId() - 1;
        //usdc.approve(address(auction), 0);
        vm.deal(seller, 2 ether);
        vm.deal(bidder, 2 ether);
        //vm.warp(block.timestamp + 50);
        vm.startPrank(seller);
        auction.bid{value: 2 ether}(currentAuctionId);
        vm.startPrank(bidder);
        // 第二次低价起拍
        vm.expectRevert("invalid highestBid");
        // 最近一次出价是2eth，当前出价不能低于2eth
        auction.bid{value: 1.2 ether}(currentAuctionId);
    }
    // 测试拍卖结果正确
    function test_bidResult() public {
        IERC20 usdc = IERC20(USDC_SEPOLIA);
        address seller = address(0xB0B);
        address bidder1 = address(0xB0123);
        address bidder2 = address(0xB0124);
        uint256 ethPrice = auction.getPriceInDollar(1) / 10 ** 8;
        vm.startPrank(admin);
        auction.start(seller, 1, address(nft), ethPrice, 3600, address(usdc));
        uint256 currentAuctionId = auction.auctionId() - 1;
        //usdc.approve(address(auction), 0);
        vm.deal(seller, 20 ether);
        vm.deal(bidder1, 20 ether);
        vm.deal(bidder2, 20 ether);

        vm.startPrank(bidder1);
        auction.bid{value: 2 ether}(currentAuctionId);
        vm.startPrank(bidder2);
        auction.bid{value: 3 ether}(currentAuctionId);
        vm.startPrank(bidder1);
        auction.bid{value: 4 ether}(currentAuctionId);

        (,,,,, address highestBidder,,,, uint256 highestBid,) = auction.auctions(currentAuctionId);

        // 最近一次出价者为bidder1，最高出价为4eth
        assertEq(highestBidder, bidder1);
        assertEq(highestBid, 4 ether);
    }

    //测试提款正确
    function test_withdraw() public {
        IERC20 usdc = IERC20(USDC_SEPOLIA);
        address seller = address(0xB0B);
        address bidder1 = address(0xB0123);
        address bidder2 = address(0xB0124);
        uint256 ethPrice = auction.getPriceInDollar(1) / 10 ** 8;
        vm.startPrank(admin);
        auction.start(seller, 1, address(nft), ethPrice, 30, address(usdc));
        uint256 currentAuctionId = auction.auctionId() - 1;
        //usdc.approve(address(auction), 0);
        vm.deal(seller, 20 ether);
        vm.deal(bidder1, 20 ether);
        vm.deal(bidder2, 20 ether);

        vm.startPrank(bidder1);
        auction.bid{value: 2 ether}(currentAuctionId);
        vm.startPrank(bidder2);
        auction.bid{value: 3 ether}(currentAuctionId);
        vm.startPrank(bidder1);
        auction.bid{value: 4 ether}(currentAuctionId);

        (,,,,, address highestBidder,,,, uint256 highestBid,) = auction.auctions(currentAuctionId);

        // 因为出价最高者为bidder1，最高价为4eth
        assertEq(highestBidder, bidder1);
        assertEq(highestBid, 4 ether);
        vm.warp(block.timestamp + 50);
        vm.startPrank(bidder2);
        // 因为出价了3eth，所以剩余17eth
        assertEq(bidder2.balance, 17 ether);
        auction.withdraw(currentAuctionId);
        // 提款了出价额3eth，所以是20eth
       assertEq(bidder2.balance, 20 ether);
    }

    //测试提款正确
    function test_withdrawNonHightestBidder() public {
        IERC20 usdc = IERC20(USDC_SEPOLIA);
        address seller = address(0xB0B);
        address bidder1 = address(0xB0123);
        address bidder2 = address(0xB0124);
        uint256 ethPrice = auction.getPriceInDollar(1) / 10 ** 8;
        vm.startPrank(admin);
        auction.start(seller, 1, address(nft), ethPrice, 30, address(usdc));
        uint256 currentAuctionId = auction.auctionId() - 1;
        //usdc.approve(address(auction), 0);
        vm.deal(seller, 20 ether);
        vm.deal(bidder1, 20 ether);
        vm.deal(bidder2, 20 ether);

        vm.startPrank(bidder1);
        auction.bid{value: 2 ether}(currentAuctionId);
        vm.startPrank(bidder2);
        auction.bid{value: 3 ether}(currentAuctionId);
        vm.startPrank(bidder1);
        auction.bid{value: 4 ether}(currentAuctionId);

        (,,,,, address highestBidder,,,, uint256 highestBid,) = auction.auctions(currentAuctionId);

        assertEq(highestBidder, bidder1);
        assertEq(highestBid, 4 ether);
        vm.warp(block.timestamp + 50);
        vm.startPrank(bidder1);
        auction.withdraw(currentAuctionId);
        // bidder1共出价2次，第一次出价2，第二次出价4，提现前余额为14，因为第二次是最高价，所以只能提现2，最终余额16
        assertEq(bidder1.balance, 16 ether);
    }}
