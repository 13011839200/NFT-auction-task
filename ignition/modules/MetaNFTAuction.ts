// 导入buildModule函数，这是定义部署模块的唯一入口
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
// 创建MetaNFTAuction部署模块，metaNFTAuctionModule为接收部署模块对象
const metaNFTAuctionModule = buildModule("MetaNFTAuction", (m) => {
  const metaNFTAuction = m.contract("MetaNFTAuction")
  return { metaNFTAuction };
});
// 通过export暴露metaNFTAuctionModule，供Hardhat-Ignition 执行或其他模块复用
export default metaNFTAuctionModule;