# 信頼性のあるリクエスト・応答パターン
;Chapter 3 - Advanced Request-Reply Patterns covered advanced uses of ØMQ's request-reply pattern with working examples. This chapter looks at the general question of reliability and builds a set of reliable messaging patterns on top of ØMQ's core request-reply pattern.

第3章「リクエスト・応答パターンの応用」ではリクエスト・応答パターンの高度な活用方法を実際に動作する例と一緒に見てきました。
このしょうでは一般的な問題である信頼性を確保する方法、および様々な信頼性のあるメッセージングパターンの構築方法を紹介します。

;In this chapter, we focus heavily on user-space request-reply patterns, reusable models that help you design your own ØMQ architectures:

この章では便利で再利用可能な以下のパターンを紹介します。

;* The Lazy Pirate pattern: reliable request-reply from the client side
;* The Simple Pirate pattern: reliable request-reply using load balancing
;* The Paranoid Pirate pattern: reliable request-reply with heartbeating
;* The Majordomo pattern: service-oriented reliable queuing
;* The Titanic pattern: disk-based/disconnected reliable queuing
;* The Binary Star pattern: primary-backup server failover
;* The Freelance pattern: brokerless reliable request-reply

* ものぐさ海賊パターン: クライアント側による信頼性のあるリクエスト・応答パターン
* 単純な海賊パターン: 負荷分散を利用したリクエスト・応答パターン
* ピラミッド海賊パターン: ハートビートを利用したリクエスト・応答パターン
* Majordomoパターン: サービス指向の信頼性のあるキューイング
* タイタニックパターン: ディスクベース・非接続な信頼性のあるキューイング
* バイナリースターパターン: プライマリー・バックアップ構成
* フリーランスパターン: ブローカー不在の信頼性のあるリクエスト・応答パターン

## 「信頼性」とは何でしょうか?


## Designing Reliability
## Client-Side Reliability (Lazy Pirate Pattern)
## Basic Reliable Queuing (Simple Pirate Pattern)
## Robust Reliable Queuing (Paranoid Pirate Pattern)
## Heartbeating
### Shrugging It Off
### One-Way Heartbeats
### Ping-Pong Heartbeats
### Heartbeating for Paranoid Pirate
## Contracts and Protocols
## Service-Oriented Reliable Queuing (Majordomo Pattern)
## Asynchronous Majordomo Pattern
## Service Discovery
## Idempotent Services
## Disconnected Reliability (Titanic Pattern)
## High-Availability Pair (Binary Star Pattern)
### Detailed Requirements
### Preventing Split-Brain Syndrome
### Binary Star Implementation
### Binary Star Reactor
## Brokerless Reliability (Freelance Pattern)
### Model One: Simple Retry and Failover
### Model Two: Brutal Shotgun Massacre
### Model Three: Complex and Nasty
## Conclusion
