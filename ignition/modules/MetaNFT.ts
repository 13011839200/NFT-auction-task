// 导入buildModule函数
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
// 创建MetaNFTModule部署模块,m是Hardhat-Ignition提供的部署管理器对象，所有合约部署依赖声明都通过m完成
const metaNFTModule = buildModule("MetaNFT", (m) => {
  // 编译并部署MetaNFT智能合约
  const metaNFT = m.contract("MetaNFT")
  // 返回合约实例
  return { metaNFT };
});
export default metaNFTModule;