// 导入buildModule函数（定义部署模块的唯一入口）
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// 创建MetaNFTAuctionProxyModule部署模块
const metaNFTAuctionProxyModule = buildModule("MetaNFTAuctionProxyModule", (m) => {
    // 从内置账户里获取第1个账户
    const proxyAdminOwner = m.getAccount(0);

    // 编译并部署NFT市场合约MetaNFTAuction
    const auctionImpl = m.contract("MetaNFTAuction");

    // 编码NFT市场合约的初始化函数调用数据calldata（字节码）
    const encodedFunctionCall = m.encodeFunctionCall(
      auctionImpl,
      "initialize",
      [proxyAdminOwner],
    );

    // 编译和部署TransparentUpgradeableProxy，通过代理合约构造器执行逻辑合约（NFT市场）的初始化函数
    const proxy = m.contract("TransparentUpgradeableProxy", [
      auctionImpl,            // 实现合约地址
      proxyAdminOwner,        // 代理的初始管理员地址
      encodedFunctionCall,    // 代理部署后自动执行的字节码
    ]);

    // 从指定合约的指定事件中，读取指定参数的数值（TransparentUpgradeableProxy部署时，会自动创建一个ProxyAdmin合约，并触发AdminChanged事件）
    const proxyAdminAddress = m.readEventArgument(
      proxy,          // 指定合约（代理合约）
      "AdminChanged", // 指定事件名称
      "newAdmin",     //  指定参数
    );

    // 将通过事件获取的ProxyAdmin地址，绑定为ProxyAdmin合约实例
    const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress);

    return { proxyAdmin, proxy };
  }
);

const metaNFTAuctionModule = buildModule("MetaNFTAuctionModule", (m) => {
  //模块依赖方法（先执行metaNFTAuctionProxyModule完成底层部署）
  const { proxy, proxyAdmin } = m.useModule(metaNFTAuctionProxyModule);

  // 将代理地址和NFT市场合约绑定，所有对代理地址的调用都会转发到实现层，前端可将代理地址直接当作MetaNFTAuction使用
  const auction = m.contractAt("MetaNFTAuction", proxy);

  return { auction, proxy, proxyAdmin };
});

// 将metaNFTAuctionModule作为导出，供Hardhat-Ignition命令行工具识别和执行
export default metaNFTAuctionModule;
