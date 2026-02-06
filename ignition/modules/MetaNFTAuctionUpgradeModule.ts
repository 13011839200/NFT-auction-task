import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// 导入MetaNFTAuctionModule模块
import MetaNFTAuctionModule from "./MetaNFTAuctionProxyModule.js";

const metaNFTAuctionUpgradeModule = buildModule("MetaNFTAuctionUpgradeModule", (m) => {
    // 获取内置账户里的第一个账户
    const proxyAdminOwner = m.getAccount(0);

    // 导入并复用
    const { proxyAdmin, proxy } = m.useModule(MetaNFTAuctionModule);

    const auctionV2 = m.contract("MetaNFTAuctionV2");

    // proxyAdminOwner（发起者）调用proxyAdmin的upgradeAndCall函数，参数是proxy，auctionV2， 0x
    m.call(proxyAdmin, "upgradeAndCall", [proxy, auctionV2, "0x"], {
      from: proxyAdminOwner,
    });

    // 将原代理地址绑定为MetaNFTAuctionV2合约实例，前端可直接通过auction交互V2合约，无需感知代理存在，给该实例配置唯一标识MetaNFTAuctionV2AtProxy
    const auction = m.contractAt("MetaNFTAuctionV2", proxy, {
      id: "MetaNFTAuctionV2AtProxy",
    });

    return { auction, proxyAdmin, proxy };
  },
);

export default metaNFTAuctionUpgradeModule;
