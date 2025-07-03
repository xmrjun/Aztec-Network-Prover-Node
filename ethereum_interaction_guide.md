# Ubuntu上创建合约交互查询脚本指南

## 1. 创建项目文件夹
```bash
mkdir -p ethereum-contract-checker
cd ethereum-contract-checker
```

## 2. 安装Python和依赖
```bash
# 更新系统
sudo apt update

# 安装Python3和pip（如果没有）
sudo apt install python3 python3-pip python3-venv

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 安装依赖包
pip install requests web3 python-dotenv
```

## 3. 创建主查询脚本
创建文件 `contract_interaction_checker.py`：

```python
#!/usr/bin/env python3
"""
合约交互次数查询脚本
查询指定钱包地址与合约的交互次数
"""

import requests
import json
import time
from datetime import datetime

class ContractInteractionChecker:
    def __init__(self, etherscan_api_key=""):
        self.etherscan_api_key = etherscan_api_key
        self.base_url = "https://api.etherscan.io/api"
        
    def get_wallet_transactions(self, wallet_address, page=1, offset=10000):
        """获取钱包所有交易记录"""
        params = {
            'module': 'account',
            'action': 'txlist',
            'address': wallet_address,
            'startblock': 0,
            'endblock': 99999999,
            'page': page,
            'offset': offset,
            'sort': 'desc',
            'apikey': self.etherscan_api_key
        }
        
        try:
            response = requests.get(self.base_url, params=params)
            data = response.json()
            
            if data['status'] == '1':
                return data['result']
            else:
                print(f"API错误: {data.get('message', '未知错误')}")
                return []
                
        except Exception as e:
            print(f"请求失败: {str(e)}")
            return []
    
    def count_contract_interactions(self, wallet_address, contract_address):
        """统计与指定合约的交互次数"""
        print(f"正在查询钱包 {wallet_address} 与合约 {contract_address} 的交互...")
        
        # 转换为小写进行比较
        contract_address = contract_address.lower()
        wallet_address = wallet_address.lower()
        
        all_transactions = []
        page = 1
        
        # 获取所有交易（分页）
        while True:
            print(f"正在获取第 {page} 页交易记录...")
            transactions = self.get_wallet_transactions(wallet_address, page=page)
            
            if not transactions:
                break
                
            all_transactions.extend(transactions)
            
            # 如果返回的交易数少于10000，说明已经是最后一页
            if len(transactions) < 10000:
                break
                
            page += 1
            time.sleep(0.2)  # 避免API限制
        
        # 筛选与目标合约的交互
        contract_interactions = []
        for tx in all_transactions:
            if tx['to'].lower() == contract_address:
                contract_interactions.append(tx)
        
        return contract_interactions, all_transactions
    
    def analyze_interactions(self, interactions):
        """分析交互数据"""
        if not interactions:
            print("没有找到与该合约的交互记录")
            return
            
        print(f"\n=== 交互分析结果 ===")
        print(f"总交互次数: {len(interactions)}")
        
        # 按日期分组统计
        daily_count = {}
        total_gas_used = 0
        total_gas_fee = 0
        
        for tx in interactions:
            # 转换时间戳
            timestamp = int(tx['timeStamp'])
            date = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d')
            
            daily_count[date] = daily_count.get(date, 0) + 1
            
            # 统计Gas使用
            total_gas_used += int(tx.get('gasUsed', 0))
            gas_price = int(tx.get('gasPrice', 0))
            gas_used = int(tx.get('gasUsed', 0))
            total_gas_fee += (gas_price * gas_used) / 1e18  # 转换为ETH
        
        print(f"总Gas消耗: {total_gas_used:,}")
        print(f"总Gas费用: {total_gas_fee:.6f} ETH")
        print(f"平均每次交互Gas费: {total_gas_fee/len(interactions):.6f} ETH")
        
        print(f"\n=== 按日期统计 ===")
        for date in sorted(daily_count.keys(), reverse=True):
            print(f"{date}: {daily_count[date]} 次交互")
        
        # 显示最近的几次交互
        print(f"\n=== 最近5次交互详情 ===")
        recent_interactions = sorted(interactions, key=lambda x: int(x['timeStamp']), reverse=True)[:5]
        
        for i, tx in enumerate(recent_interactions, 1):
            timestamp = int(tx['timeStamp'])
            date_time = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M:%S')
            gas_fee = (int(tx.get('gasPrice', 0)) * int(tx.get('gasUsed', 0))) / 1e18
            
            print(f"{i}. 时间: {date_time}")
            print(f"   交易哈希: {tx['hash']}")
            print(f"   Gas费用: {gas_fee:.6f} ETH")
            print(f"   状态: {'成功' if tx.get('txreceipt_status') == '1' else '失败'}")
            print()

def main():
    # 配置参数
    WALLET_ADDRESS = "0x5BFC30C616173A090B69e5a855d8F5D7B6c86efC"
    CONTRACT_ADDRESS = "0xeE6d4e937f0493Fb461F28A75Cf591f1dBa8704E"
    
    # Etherscan API Key (可选，没有key也能使用但有限制)
    API_KEY = ""  # 如果有API key，在这里填写
    
    # 创建查询器
    checker = ContractInteractionChecker(API_KEY)
    
    print("=== 合约交互查询工具 ===")
    print(f"钱包地址: {WALLET_ADDRESS}")
    print(f"合约地址: {CONTRACT_ADDRESS}")
    print()
    
    # 执行查询
    interactions, all_txs = checker.count_contract_interactions(WALLET_ADDRESS, CONTRACT_ADDRESS)
    
    print(f"\n钱包总交易数: {len(all_txs)}")
    print(f"与目标合约交互数: {len(interactions)}")
    
    if interactions:
        checker.analyze_interactions(interactions)
        
        # 保存详细结果到文件
        with open('interaction_details.json', 'w', encoding='utf-8') as f:
            json.dump(interactions, f, indent=2, ensure_ascii=False)
        print(f"\n详细交互数据已保存到 interaction_details.json")

if __name__ == "__main__":
    main()
```

## 4. 创建配置文件（可选）
创建 `.env` 文件（如果有Etherscan API key）：
```bash
echo "ETHERSCAN_API_KEY=你的API密钥" > .env
```

## 5. 创建运行脚本
创建 `run_checker.sh`：
```bash
#!/bin/bash
echo "启动合约交互查询..."
source venv/bin/activate
python3 contract_interaction_checker.py
```

## 6. 使用方法
```bash
# 进入项目目录
cd ethereum-contract-checker

# 激活虚拟环境
source venv/bin/activate

# 运行查询脚本
python3 contract_interaction_checker.py

# 或者使用运行脚本
chmod +x run_checker.sh
./run_checker.sh
```

## 7. 获取Etherscan API Key（推荐）
1. 访问 https://etherscan.io/apis
2. 注册账号并创建API key
3. 将API key添加到脚本中的 `API_KEY` 变量

## 8. 功能特点
- ✅ 统计总交互次数
- ✅ 按日期分组统计
- ✅ 计算总Gas费用
- ✅ 显示最近交互详情
- ✅ 保存详细数据到JSON文件
- ✅ 支持大量交易的分页查询

## 9. 输出示例
```
=== 交互分析结果 ===
总交互次数: 7
总Gas消耗: 1,234,567
总Gas费用: 0.013710 ETH
平均每次交互Gas费: 0.001959 ETH

=== 按日期统计 ===
2024-01-15: 3 次交互
2024-01-14: 4 次交互
```

这个脚本会准确统计你的钱包与指定合约的所有交互记录！