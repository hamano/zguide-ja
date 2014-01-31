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
;Most people who speak of "reliability" don't really know what they mean. We can only define reliability in terms of failure. That is, if we can handle a certain set of well-defined and understood failures, then we are reliable with respect to those failures. No more, no less. So let's look at the possible causes of failure in a distributed ØMQ application, in roughly descending order of probability:

人々はよく「信頼性」という言葉を口にしますが、ほとんどの人はその本当の意味を理解していません。
ここでは障害時における「信頼性」という言葉を定義します。
もしも既知および未知の障害に対して適切にエラー処理を行うことができた場合、障害に対して信頼性があると言うことが出来ます。
これ以上でもこれ以下でもありません。
ですので、まずはØMQの分散アプリケーションで発生しうる障害について見て行きましょう。

;* Application code is the worst offender. It can crash and exit, freeze and stop responding to input, run too slowly for its input, exhaust all memory, and so on.
;* System code--such as brokers we write using ØMQ--can die for the same reasons as application code. System code should be more reliable than application code, but it can still crash and burn, and especially run out of memory if it tries to queue messages for slow clients.
;* Message queues can overflow, typically in system code that has learned to deal brutally with slow clients. When a queue overflows, it starts to discard messages. So we get "lost" messages.
;* Hardware can fail and take with it all the processes running on that box.
;* Networks can fail in exotic ways, e.g., some ports on a switch may die and those parts of the network become inaccessible.
;* Entire data centers can be struck by lightning, earthquakes, fire, or more mundane power or cooling failures.

* アプリケーションにとっての最大の罪はクラッシュして以上終了したり、フリーズして入力を受け付けなくなったり、メモリを使い果たして遅くなったりする事です。
* アプリケーションプログラムが原因で、ブローカーなどのシステムプログラムがクラッシュしてしまう障害。システムプログラムはアプリケーションプログラムより信頼性が求められますが、クラッシュしたり、メモリを使い果たしてしまう事は起こり得ます。
* システムプログラムが遅いクライアントの相手をすると、メッセージキューが溢れてしまう事があります。キューが溢れるとメッセージを捨ててしまうのでメッセージが喪失してしまう障害が発生します。
* ハードウェアに障害が発生すると、そのサーバー上で動作している全てのプロセスが影響を受けます。
* ネットワーク障害が発生すると、不可思議な現象を引き起こす場合があります。例えばスイッチのポートが故障することで部分的なネットワークにアクセス不能になります。
* データセンター全体で障害が発生する可能性があります。例えば地震、落雷、火事、空調の故障などです。

;To make a software system fully reliable against all of these possible failures is an enormously difficult and expensive job and goes beyond the scope of this book.

これら全ての障害に対して、信頼性を高める対策をソフトウェアで行うのは非常に高価で難しいことであり、本書の範疇を超えています。

;Because the first five cases in the above list cover 99.9% of real world requirements outside large companies (according to a highly scientific study I just ran, which also told me that 78% of statistics are made up on the spot, and moreover never to trust a statistic that we didn't falsify ourselves), that's what we'll examine. If you're a large company with money to spend on the last two cases, contact my company immediately! There's a large hole behind my beach house waiting to be converted into an executive swimming pool.

現実世界で発生する障害の99.9%は最初の5つに分類されるでしょう。(これは私が行った十分に科学的な調査です)
もし最後の2例の問題にお金をつぎ込みたいと考えているお金の余っている大企業が居られましたら是非とも我社にご連絡下さい。
ビーチハウスの裏側に高級プールを作りましょう。

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
