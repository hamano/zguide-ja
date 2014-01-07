# リクエスト・応答パターンの応用
;In Chapter 2 - Sockets and Patterns we worked through the basics of using ØMQ by developing a series of small applications, each time exploring new aspects of ØMQ. We'll continue this approach in this chapter as we explore advanced patterns built on top of ØMQ's core request-reply pattern.

「第2章 - ソケットとパターン」ではØMQを使った一連の小さなアプリケーションを開発する事でØMQの新しい側面を探って来ました。
この章では引き続き同様の方法で、ØMQのコアとなるリクエスト・応答パターンの応用方法について探っていきます。

;We'll cover:
この章では、

;* How the request-reply mechanisms work
;* How to combine REQ, REP, DEALER, and ROUTER sockets
;* How ROUTER sockets work, in detail
;* The load balancing pattern
;* Building a simple load balancing message broker
;* Designing a high-level API for ØMQ
;* Building an asynchronous request-reply server
;* A detailed inter-broker routing example

* どの様にリクエスト・応答のメカニズムが動作するか
* REQ、REP、DEALER、ROUTERなどのソケットを組み合わせる方法
* どの様にROUTERソケットが動作するか、とその詳細
* 負荷分散パターン
* 負荷分散メッセージブローカーを構築する
* 高レベルリクエスト・応答サーバーの設計
* 非同期なルリクエスト・応答サーバーの構築
* 内部ブローカーのルーティング例

## リクエスト・応答のメカニズム
;We already looked briefly at multipart messages. Let's now look at a major use case, which is reply message envelopes. An envelope is a way of safely packaging up data with an address, without touching the data itself. By separating reply addresses into an envelope we make it possible to write general purpose intermediaries such as APIs and proxies that create, read, and remove addresses no matter what the message payload or structure is.

これまでマルチパートメッセージについて簡単に学んできました。
ここでは応答メッセージエンベローブという主要なユースケースについて見ていきます。
エンベロープはデータ本体に触れること無くデータに宛先を付けてパッケージ化する方法です。
宛先をエンベロープに分離することで、メッセージ本体の構造に関わらず宛先を読み書き、削除を行うことの出来る汎用的なAPIや仲介者を構築することが可能になります。

;In the request-reply pattern, the envelope holds the return address for replies. It is how a ØMQ network with no state can create round-trip request-reply dialogs.

リクエスト・応答パターンでは、応答する際の返信アドレスをエンベロープに記述します。
これによりØMQネットワークは状態を持たずにリクエスト・応答の一連のやりとり実現出来ます。

;When you use REQ and REP sockets you don't even see envelopes; these sockets deal with them automatically. But for most of the interesting request-reply patterns, you'll want to understand envelopes and particularly ROUTER sockets. We'll work through this step-by-step.

REQ、REPソケットを利用する際、わざわざエンベロープを参照する必要はありません。これらはソケットが自動的に行なってくれます。
しかしここはリクエスト・応答パターンの面白い所ですし、とりわけROUTERソケットのエンベロープついて学んでおいて損は無いでしょう。
これからそれらを一歩一歩学んでいきます。

### 単純な応答パケット
;A request-reply exchange consists of a request message, and an eventual reply message. In the simple request-reply pattern, there's one reply for each request. In more advanced patterns, requests and replies can flow asynchronously. However, the reply envelope always works the same way.

リクエスト・応答のやり取りはリクエストメッセージとそれに対する応答メッセージかで成立します。
単純なリクエスト・応答パターンでは各リクエストに対して1回の応答を行います。
もっと高度なパターンだと、リクエストと応答は非同期で行われます。
しかしながら応答エンベロープはいつも同じように動作します。

;The ØMQ reply envelope formally consists of zero or more reply addresses, followed by an empty frame (the envelope delimiter), followed by the message body (zero or more frames). The envelope is created by multiple sockets working together in a chain. We'll break this down.

ØMQの応答エンベロープは正確には0以上の返信先アドレス、続いて空のフレーム(エンベロープの区切り)、そしてメッセージ本体(0以上のフレーム)で構成されます。
エンベロープは複数のソケット動作する中で生成されます。
これをもっと具体的に見ていきます。

;We'll start by sending "Hello" through a REQ socket. The REQ socket creates the simplest possible reply envelope, which has no addresses, just an empty delimiter frame and the message frame containing the "Hello" string. This is a two-frame message.

「Hello」というメッセージをREQソケットで送信する場合を考えます。
REQソケットはアドレスを持たない空の区切りフレームと「Hello」というメッセージフレームから構成される最も単純な応答エンベロープを生成します。
これは2つのフレームで構成されたメッセージです。

![最小の応答エンベロープ](images/fig26.eps)

;The REP socket does the matching work: it strips off the envelope, up to and including the delimiter frame, saves the whole envelope, and passes the "Hello" string up the application. Thus our original Hello World example used request-reply envelopes internally, but the application never saw them.

REPソケットは区切りフレームを含む全体のエンベロープを退避します。そして残りの「Hello」という文字列がアプリケーションに渡されます。
最初のHello Worldのサンプルコードはリクエスト・応答のエンベロープは内部的に処理されていますのでアプリケーションでこれを意識する事はありません。

;If you spy on the network data flowing between hwclient and hwserver, this is what you'll see: every request and every reply is in fact two frames, an empty frame and then the body. It doesn't seem to make much sense for a simple REQ-REP dialog. However you'll see the reason when we explore how ROUTER and DEALER handle envelopes.

hwclientとhwserverの間を流れるネットワークデータを監視してみると、全てのリクエストと応答は空のフレームとメッセージ本体の2つのフレームで構成されていることを確認できるでしょう。
この様に単純なリクエスト・応答のやり取りではエンベロープは付加されていません。
しかし、ROUTERとDEALERソケットの処理を監視すると、エンベロープに宛先が付加されているのを確認できるはずです。

### 拡張された応答エンベロープ
;Now let's extend the REQ-REP pair with a ROUTER-DEALER proxy in the middle and see how this affects the reply envelope. This is the extended request-reply pattern we already saw in Chapter 2 - Sockets and Patterns. We can, in fact, insert any number of proxy steps. The mechanics are the same.

![拡張されたリクエスト・応答パターン](images/fig27.eps)


### What's This Good For?
### Recap of Request-Reply Sockets

## リクエスト・応答の組み合わせ
### REQとREPの組み合わせ
### The DEALER to REP Combination
### The REQ to ROUTER Combination
### The DEALER to ROUTER Combination
### The DEALER to DEALER Combination
### The ROUTER to ROUTER Combination
### Invalid Combinations

## Exploring ROUTER Sockets
### Identities and Addresses
### ROUTER Error Handling

## The Load Balancing Pattern
### ROUTER Broker and REQ Workers
### ROUTER Broker and DEALER Workers
### A Load Balancing Message Broker

## A High-Level API for ØMQ
### Features of a Higher-Level API
### The CZMQ High-Level API

## The Asynchronous Client/Server Pattern

## Worked Example: Inter-Broker Routing
### Establishing the Details
### Architecture of a Single Cluster
### Scaling to Multiple Clusters
### Federation Versus Peering
### The Naming Ceremony
### Prototyping the State Flow
### Prototyping the Local and Cloud Flows
### Putting it All Together
