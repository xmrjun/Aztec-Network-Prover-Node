#!/usr/bin/env python3
"""
使用RPC节点查询合约交互的脚本
直接从区块链查询数据，更准确可靠
"""

import requests
import json
from datetime import datetime
import time

class RPCContractChecker:
    def __init__(self, rpc_url):
        self.rpc_url = rpc_url
        self.session = requests.Session()
    
    def rpc_call(self, method, params):
        """执行RPC调用"""
        payload = {
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": 1
        }
        
        try:
            response = self.session.post(self.rpc_url, json=payload)
            data = response.json()
            return data.get('result')
        except Exception as e:
            print(f"RPC调用失败: {e}")
            return None
    
    def get_latest_block(self):
        """获取最新区块号"""
        result = self.rpc_call("eth_blockNumber", [])
        return int(result, 16) if result else 0
    
    def get_block_with_transactions(self, block_number):
        """获取区块及其交易"""
        block_hex = hex(block_number)
        result = self.rpc_call("eth_getBlockByNumber", [block_hex, True])
        return result
    
    def analyze_transaction(self, tx, target_contract):
        """分析单个交易"""
        if not tx or not tx.get('to'):
            return None
            
        if tx['to'].lower() == target_contract.lower():
            return {
                'hash': tx['hash'],
                'from': tx['from'],
                'to': tx['to'],
                'value': int(tx['value'], 16),
                'gas': int(tx['gas'], 16),
                'gasPrice': int(tx['gasPrice'], 16),
                'blockNumber': int(tx['blockNumber'], 16),
                'blockHash': tx['blockHash'],
                'transactionIndex': int(tx['transactionIndex'], 16)
            }
        return None
    
    def get_transaction_receipt(self, tx_hash):
        """获取交易回执（包含实际gas使用量）"""
        return self.rpc_call("eth_getTransactionReceipt", [tx_hash])
    
    def scan_recent_blocks(self, wallet_address, contract_address, block_count=1000):
        """扫描最近的区块查找交互"""
        print(f"开始扫描最近 {block_count} 个区块...")
        
        latest_block = self.get_latest_block()
        start_block = max(0, latest_block - block_count)
        
        wallet_address = wallet_address.lower()
        contract_address = contract_address.lower()
        interactions = []
        
        print(f"扫描区块范围: {start_block} -> {latest_block}")
        
        for block_num in range(start_block, latest_block + 1):
            if block_num % 100 == 0:
                print(f"正在扫描区块 {block_num}...")
            
            block = self.get_block_with_transactions(block_num)
            if not block or not block.get('transactions'):
                continue
            
            for tx in block['transactions']:
                # 检查是否是目标钱包发起的交易
                if (tx.get('from', '').lower() == wallet_address and 
                    tx.get('to', '').lower() == contract_address):
                    
                    interaction = self.analyze_transaction(tx, contract_address)
                    if interaction:
                        # 获取交易回执
                        receipt = self.get_transaction_receipt(tx['hash'])
                        if receipt:
                            interaction['gasUsed'] = int(receipt['gasUsed'], 16)
                            interaction['status'] = receipt['status']
                            interaction['timestamp'] = int(block['timestamp'], 16)
                        
                        interactions.append(interaction)
                        print(f"找到交互: 区块 {block_num}, 交易 {tx['hash'][:10]}...")
        
        return interactions
    
    def use_etherscan_fallback(self, wallet_address, contract_address):
        """使用Etherscan作为备选方案"""
        print("使用Etherscan API作为备选查询方案...")
        
        url = "https://api.etherscan.io/api"
        params = {
            'module': 'account',
            'action': 'txlist',
            'address': wallet_address,
            'startblock': 0,
            'endblock': 99999999,
            'page': 1,
            'offset': 10000,
            'sort': 'desc'
        }
        
        try:
            response = requests.get(url, params=params)
            data = response.json()
            
            if data['status'] == '1':
                all_txs = data['result']
                contract_interactions = []
                
                for tx in all_txs:
                    if tx.get('to', '').lower() == contract_address.lower():
                        contract_interactions.append({
                            'hash': tx['hash'],
                            'from': tx['from'],
                            'to': tx['to'],
                            'value': int(tx['value']),
                            'gas': int(tx['gas']),
                            'gasPrice': int(tx['gasPrice']),
                            'gasUsed': int(tx['gasUsed']),
                            'blockNumber': int(tx['blockNumber']),
                            'timestamp': int(tx['timeStamp']),
                            'status': '0x1' if tx.get('txreceipt_status') == '1' else '0x0'
                        })
                
                return contract_interactions
            else:
                print(f"Etherscan API错误: {data.get('message', '未知错误')}")
                return []
                
        except Exception as e:
            print(f"Etherscan查询失败: {e}")
            return []
    
    def analyze_interactions(self, interactions):
        """分析交互数据"""
        if not interactions:
            print("没有找到与该合约的交互记录")
            return
        
        print(f"\n=== 合约交互分析结果 ===")
        print(f"总交互次数: {len(interactions)}")
        
        # 计算总gas费用
        total_gas_fee = 0
        successful_txs = 0
        
        for tx in interactions:
            if tx.get('gasUsed') and tx.get('gasPrice'):
                gas_fee = (tx['gasUsed'] * tx['gasPrice']) / 1e18
                total_gas_fee += gas_fee
                
                if tx.get('status') in ['0x1', '1']:
                    successful_txs += 1
        
        print(f"成功交易数: {successful_txs}")
        print(f"总Gas费用: {total_gas_fee:.6f} ETH")
        if len(interactions) > 0:
            print(f"平均Gas费用: {total_gas_fee/len(interactions):.6f} ETH")
        
        # 按日期统计
        daily_count = {}
        for tx in interactions:
            if tx.get('timestamp'):
                date = datetime.fromtimestamp(tx['timestamp']).strftime('%Y-%m-%d')
                daily_count[date] = daily_count.get(date, 0) + 1
        
        if daily_count:
            print(f"\n=== 按日期统计 ===")
            for date in sorted(daily_count.keys(), reverse=True):
                print(f"{date}: {daily_count[date]} 次交互")
        
        # 显示最近交互详情
        print(f"\n=== 最近交互详情 ===")
        recent_interactions = sorted(interactions, 
                                   key=lambda x: x.get('timestamp', 0), 
                                   reverse=True)[:5]
        
        for i, tx in enumerate(recent_interactions, 1):
            timestamp = tx.get('timestamp', 0)
            if timestamp:
                date_time = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M:%S')
            else:
                date_time = "未知时间"
            
            gas_fee = 0
            if tx.get('gasUsed') and tx.get('gasPrice'):
                gas_fee = (tx['gasUsed'] * tx['gasPrice']) / 1e18
            
            status = "成功" if tx.get('status') in ['0x1', '1'] else "失败"
            
            print(f"{i}. 时间: {date_time}")
            print(f"   交易哈希: {tx['hash']}")
            print(f"   区块号: {tx.get('blockNumber', 'N/A')}")
            print(f"   Gas费用: {gas_fee:.6f} ETH")
            print(f"   状态: {status}")
            print()

def main():
    # 配置参数
    RPC_URL = "https://go.getblock.io/43ca069a0ff24c2bb8d9b98791b9f57f"
    WALLET_ADDRESS = "0x5BFC30C616173A090B69e5a855d8F5D7B6c86efC"
    CONTRACT_ADDRESS = "0xeE6d4e937f0493Fb461F28A75Cf591f1dBa8704E"
    
    print("=== RPC合约交互查询工具 ===")
    print(f"RPC节点: {RPC_URL}")
    print(f"钱包地址: {WALLET_ADDRESS}")
    print(f"合约地址: {CONTRACT_ADDRESS}")
    print()
    
    checker = RPCContractChecker(RPC_URL)
    
    # 测试RPC连接
    latest_block = checker.get_latest_block()
    if latest_block > 0:
        print(f"RPC连接成功，最新区块: {latest_block}")
        
        # 先扫描最近的区块
        interactions = checker.scan_recent_blocks(WALLET_ADDRESS, CONTRACT_ADDRESS, 2000)
        
        # 如果没找到，使用Etherscan备选方案
        if not interactions:
            print("RPC扫描未找到交互，使用Etherscan备选查询...")
            interactions = checker.use_etherscan_fallback(WALLET_ADDRESS, CONTRACT_ADDRESS)
        
    else:
        print("RPC连接失败，直接使用Etherscan查询...")
        interactions = checker.use_etherscan_fallback(WALLET_ADDRESS, CONTRACT_ADDRESS)
    
    # 分析结果
    checker.analyze_interactions(interactions)
    
    # 保存详细数据
    if interactions:
        with open('rpc_interaction_details.json', 'w', encoding='utf-8') as f:
            json.dump(interactions, f, indent=2, ensure_ascii=False)
        print(f"详细交互数据已保存到 rpc_interaction_details.json")

if __name__ == "__main__":
    main()