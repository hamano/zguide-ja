# 信頼性のあるリクエスト・応答パターン
;Chapter 3 - Advanced Request-Reply Patterns covered advanced uses of ØMQ's request-reply pattern with working examples. This chapter looks at the general question of reliability and builds a set of reliable messaging patterns on top of ØMQ's core request-reply pattern.

第3章「リクエスト・応答パターンの応用」ではリクエスト・応答パターンの高度な応用方法を実際に動作する例と共に見てきました。
この章では一般的な問題である信頼性を確保する方法、および様々な信頼性のあるメッセージングパターンの構築方法を紹介します。

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
* 神経質な海賊パターン: ハートビートを利用したリクエスト・応答パターン
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
ビーチハウスの裏側に高級プールを作って頂きたいです。

## 信頼性の設計
;So to make things brutally simple, reliability is "keeping things working properly when code freezes or crashes", a situation we'll shorten to "dies". However, the things we want to keep working properly are more complex than just messages. We need to take each core ØMQ messaging pattern and see how to make it work (if we can) even when code dies.

とても単純な事なのですが、信頼性とはコードがフリーズしたりクラッシュしてしまい、いわゆる「落ちた」という状況であっても、正しく動作し続けることです。
しかし、正しく動作し続けるという事は思っている以上に大変な事です。
まずはØMQメッセージングパターン毎にどの様な障害が発生し得るか考えてみる必要があるでしょう。

;Let's take them one-by-one:
ひとつずつ見ていきます。

;* Request-reply: if the server dies (while processing a request), the client can figure that out because it won't get an answer back. Then it can give up in a huff, wait and try again later, find another server, and so on. As for the client dying, we can brush that off as "someone else's problem" for now.
;* Pub-sub: if the client dies (having gotten some data), the server doesn't know about it. Pub-sub doesn't send any information back from client to server. But the client can contact the server out-of-band, e.g., via request-reply, and ask, "please resend everything I missed". As for the server dying, that's out of scope for here. Subscribers can also self-verify that they're not running too slowly, and take action (e.g., warn the operator and die) if they are.
;* Pipeline: if a worker dies (while working), the ventilator doesn't know about it. Pipelines, like the grinding gears of time, only work in one direction. But the downstream collector can detect that one task didn't get done, and send a message back to the ventilator saying, "hey, resend task 324!" If the ventilator or collector dies, whatever upstream client originally sent the work batch can get tired of waiting and resend the whole lot. It's not elegant, but system code should really not die often enough to matter.

* リクエスト・応答パターン: リクエストの処理中にサーバーが落ちてしまった場合、クライアントは応答が返ってこないので障害の発生を検知することが出来ます。そしてリクエストを諦めたり、再試行を行ったり、別のサーバーを探すことが可能です。クライアントが落ちてしまった場合は「別のなにかの問題」として除外することが出来ます。
* Pub-subパターン: クライアントが落ちた場合、サーバーはこれを検知することが出来ません。Pub-subパターンではクライアントからサーバーに対して一切の情報を送信しないからです。ただし、クライアントは別の経路、例えばリクエスト応答パターンを利用して「取りこぼしたメッセージを再送して下さい」と要求することは可能です。サーバーが落ちてしまった場合はここでは扱いません。また、サブスクライバーはパブリッシャーの動作が遅くなったことを検知して警告を通知したり、終了させたりすることができます。
* パイプラインパターン: ワーカーが処理中に落ちた場合でもベンチレーターはそれを検知することが出来ません。パイプラインパターンは回っている歯車のようなもので、処理は一方方向にしか流れません。しかし下流のコレクターは特定のタスクが処理されなかったことを検知することが可能です。そしてベンチレーターに対して「おい、タスク324を再送してくれ!」という様なメッセージを送信することが可能です。ベンチレーターやコレクターが落ちてしまった場合はどうでしょうか、上流のクライアントはリクエスト全体を再送することが可能です。これはあまり賢い方法ではありませんが、そもそもシステムコードは頻繁に落ちるべきではありません。

;In this chapter we'll focus on just on request-reply, which is the low-hanging fruit of reliable messaging.

この章では、リクエスト・応答パターンに焦点を当てて信頼性のあるメッセージングを学んでいきます。

;The basic request-reply pattern (a REQ client socket doing a blocking send/receive to a REP server socket) scores low on handling the most common types of failure. If the server crashes while processing the request, the client just hangs forever. If the network loses the request or the reply, the client hangs forever.

REQソケットがREPソケットに対して同期的に送受信を行うリクエスト・応答パターンでは、極めて一般的な障害が発生します。
もしもリクエストの処理中にサーバーがクラッシュした場合、クライアントは永久に固まってしまいます。
そして、もしネットワークがリクエストや応答を喪失した場合でもクライアントは永久に固まってしまうでしょう。

;Request-reply is still much better than TCP, thanks to ØMQ's ability to reconnect peers silently, to load balance messages, and so on. But it's still not good enough for real work. The only case where you can really trust the basic request-reply pattern is between two threads in the same process where there's no network or separate server process to die.

リクエスト応答パターンは、ØMQの再接続する機能や、負荷分散などの機能を持っており、通常のTCPソケットに比べて十分優れています。
しかし現実にはこれだけでは不十分でしょう。
リクエスト・応答パターンにおいて信頼性があると言える唯一の状況は、同一プロセスにある2つのスレッドでこれを行う場合のみでしょう。

;However, with a little extra work, this humble pattern becomes a good basis for real work across a distributed network, and we get a set of reliable request-reply (RRR) patterns that I like to call the Pirate patterns (you'll eventually get the joke, I hope).

しかし、分散ネットワークの基礎となる幾つかの工夫を行うことで、私達が「海賊パターン」と呼んでいる信頼性のあるリクエスト応答パターンを実現する事が出来ます。

;There are, in my experience, roughly three ways to connect clients to servers. Each needs a specific approach to reliability:

私の経験によると、サーバーからクライアントに接続する方法は3つに分類され、信頼性を高める方法はそれぞれ異なります。

;* Multiple clients talking directly to a single server. Use case: a single well-known server to which clients need to talk. Types of failure we aim to handle: server crashes and restarts, and network disconnects.
;* Multiple clients talking to a broker proxy that distributes work to multiple workers. Use case: service-oriented transaction processing. Types of failure we aim to handle: worker crashes and restarts, worker busy looping, worker overload, queue crashes and restarts, and network disconnects.
;* Multiple clients talking to multiple servers with no intermediary proxies. Use case: distributed services such as name resolution. Types of failure we aim to handle: service crashes and restarts, service busy looping, service overload, and network disconnects.

* 複数のクライアントが単一のサーバーと直接通信する場合。考えられる障害はサーバーの再起動やクラッシュ、ネットワークの切断です。
* 複数のクライアントがブローカーなどのプロキシを経由して複数のワーカーと通信する場合。これはサービス指向のトランザクションを処理する場合などに使われます。考えられる障害はワーカーの再起動やクラッシュ、ワーカーのビジーループ、ワーカーの高負荷、キューのクラッシュや再起動、ネットワークの切断です。
* 複数のクライアントが複数のサーバーとプロキシを経由せずに通信する場合。名前解決などによるサービスの分散方法です。考えられる障害はサービスのビジーループ、サービスの高負荷、ネットワークの切断です。

;Each of these approaches has its trade-offs and often you'll mix them. We'll look at all three in detail.

これらの方法にはそれぞれ利点と欠点があり、時にはこれらが組み合わさる場合もあるでしょう。
これら3つについて詳しく見ていきます。

## クライアント側での信頼性(ものぐさ海賊パターン)
;We can get very simple reliable request-reply with some changes to the client. We call this the Lazy Pirate pattern. Rather than doing a blocking receive, we:

クライアントにちょっとした工夫を行うことで、リクエスト・応答パターンの信頼性を高めることが可能です。
そのためにはブロッキングで受信を行うのではなく、非同期で以下のことを行います。

;* Poll the REQ socket and receive from it only when it's sure a reply has arrived.
;* Resend a request, if no reply has arrived within a timeout period.
;* Abandon the transaction if there is still no reply after several requests.

* REQソケットを監視して、間違いなくメッセージが到着している場合のみ受信を行う。
* 一定の時間応答が返ってこない場合はリクエストを再送信する。
* 何度かリクエストを送信しても応答が返ってこなかった場合は諦めます。

;If you try to use a REQ socket in anything other than a strict send/receive fashion, you'll get an error (technically, the REQ socket implements a small finite-state machine to enforce the send/receive ping-pong, and so the error code is called "EFSM"). This is slightly annoying when we want to use REQ in a pirate pattern, because we may send several requests before getting a reply.

REQソケットを利用して厳密に送信・受信の順序を守らなかった場合はエラーが発生します。技術的に説明すると、REQソケットは有限オートマトンとして実装されていて送受信を行うことで状態遷移を行います。そして異常な遷移が行われるとエラーコード「EFSM」を返します。
ですから、REQソケットを利用してこの海賊パターンを行う場合、応答を受け取る前に送信する可能性があるので、ちょっと面倒な事が起こります。

;The pretty good brute force solution is to close and reopen the REQ socket after an error:

この問題の強引で手っ取り早い解決方法は、REQソケットでエラーが発生したら、一旦クローズして再接続する事です。

~~~ {caption="lpclient: ものぐさ海賊クライアント"}
include(examples/EXAMPLE_LANG/lpclient.EXAMPLE_EXT)
~~~

;Run this together with the matching server:
こちらのサーバーも実行してください。

~~~ {caption="lpserver: ものぐさ海賊サーバー"}
include(examples/EXAMPLE_LANG/lpclient.EXAMPLE_EXT)
~~~

![ものぐさ海賊パターン](images/fig47.eps)

;To run this test case, start the client and the server in two console windows. The server will randomly misbehave after a few messages. You can check the client's response. Here is typical output from the server:

このサンプルコードを実行するには、ターミナルを2つ立ち上げてクライアントとサーバーを起動します。
このサーバーはランダムに障害をシミュレートし、以下の様なメッセージを出力します。

~~~
I: normal request (1)
I: normal request (2)
I: normal request (3)
I: simulating CPU overload
I: normal request (4)
I: simulating a crash
~~~

;And here is the client's response:
そして以下はクライアントの出力です。

~~~
I: connecting to server...
I: server replied OK (1)
I: server replied OK (2)
I: server replied OK (3)
W: no response from server, retrying...
I: connecting to server...
W: no response from server, retrying...
I: connecting to server...
E: server seems to be offline, abandoning
~~~

;The client sequences each message and checks that replies come back exactly in
 order: that no requests or replies are lost, and no replies come back more than once, or out of order. Run the test a few times until you're convinced that this mechanism actually works. You don't need sequence numbers in a production application; they just help us trust our design.

クライアントは応答メッセージのシーケンス番号を見て、メッセージが失われていないかどうかを確認しています。
このメカニズムが期待通り動作しているか確信が持てるまでこのサンプルコードを何度でも実行してみてください。
実際のアプリケーションではシーケンス番号は必要ありません、ここでは設計の正しさを確かめるために利用してるだけです。

;The client uses a REQ socket, and does the brute force close/reopen because REQ sockets impose that strict send/receive cycle. You might be tempted to use a DEALER instead, but it would not be a good decision. First, it would mean emulating the secret sauce that REQ does with envelopes (if you've forgotten what that is, it's a good sign you don't want to have to do it). Second, it would mean potentially getting back replies that you didn't expect.

クライアントはREQソケットを利用していますので、送受信の順序を守るために強制的にソケット閉じて再接続を行っています。
ここでREQソケットの代わりにDEALERソケットを使おうと考えるかもしれませんが、これはあまり良くありません。
まず、REQソケットのエンベロープを模倣するのが面倒ですし、期待しない応答が返ってくる可能性があります。

;Handling failures only at the client works when we have a set of clients talking to a single server. It can handle a server crash, but only if recovery means restarting that same server. If there's a permanent error, such as a dead power supply on the server hardware, this approach won't work. Because the application code in servers is usually the biggest source of failures in any architecture, depending on a single server is not a great idea.

これは複数のクライアントから単一のサーバーに対して通信する場合のみに適用できる障害対策であり、サーバーがクラッシュした場合は自動的に再起動することを期待しています。
例えばハードウェア障害や電源供給が断たれるなどの恒久的なエラーが発生した場合はこの対策では不十分です。
一般的にアプリケーションコードは障害の原因になりやすいので単一のサーバーに依存したアーキテクチャー自体があまり良くありません。

;So, pros and cons:
利点と欠点をまとめます。

;* Pro: simple to understand and implement.
;* Pro: works easily with existing client and server application code.
;* Pro: ØMQ automatically retries the actual reconnection until it works.
;* Con: doesn't failover to backup or alternate servers.

* 利点: 理解しやすくて実装が簡単。
* 利点: サーバーアプリケーションの改修は必要なく、クライアント側の変更もわずかです。
* 利点: 接続が成功するまでØMQが自動的に再接続を行ってくれます。
* 欠点: 代替のサーバーにフェイルオーバーしません。

## 信頼性のあるキューイング(単純な海賊パターン)
;Our second approach extends the Lazy Pirate pattern with a queue proxy that lets us talk, transparently, to multiple servers, which we can more accurately call "workers". We'll develop this in stages, starting with a minimal working model, the Simple Pirate pattern.

2番目に紹介する方法は複数のサーバーと透過的に通信を行うキュープロキシを用いてものぐさ海賊パターンを拡張します。
まずは単純な海賊パターンが最低限動作する小さなモデルで実装していきます。

;In all these Pirate patterns, workers are stateless. If the application requires some shared state, such as a shared database, we don't know about it as we design our messaging framework. Having a queue proxy means workers can come and go without clients knowing anything about it. If one worker dies, another takes over. This is a nice, simple topology with only one real weakness, namely the central queue itself, which can become a problem to manage, and a single point of failure.

全ての海賊パターンにおいて、ワーカーはステートレスで動作します。
もしアプリケーションがデーターベースなどに状態を保存したい場合でもメッセージングフレームワークはこれに関知しません。
キュープロキシはクライアントについて何も知らずにやってくるメッセージをそのまま転送するだけの役割を持っています。
こうした方がワーカーが落ちてしまった場合でも別のワーカーにメッセージを渡すだけで良いので都合が良いのです。
これはなかなか単純で良いトポロジーですが中央キューが単一故障点になってしまうという欠点があります。

![単純な海賊パターン](images/fig48.eps)

;The basis for the queue proxy is the load balancing broker from Chapter 3 - Advanced Request-Reply Patterns. What is the very minimum we need to do to handle dead or blocked workers? Turns out, it's surprisingly little. We already have a retry mechanism in the client. So using the load balancing pattern will work pretty well. This fits with ØMQ's philosophy that we can extend a peer-to-peer pattern like request-reply by plugging naive proxies in the middle.

キュープロキシの基本的な仕組みは第3章「リクエスト・応答パターンの応用」で紹介した負荷分散ブローカーと同じです。
ワーカーが落ちたりブロックしたりする障害に対して、どの様な対応を最低限行う必要があるでしょうか?
クライアントには再試行が実装されていますので、負荷分散パターンが効果的に機能します。
これはまさしくØMQの哲学に適合し、中間にプロキシを介する事でP2Pパターンに拡張することが可能です。

;We don't need a special client; we're still using the Lazy Pirate client. Here is the queue, which is identical to the main task of the load balancing broker:

これには特別なクライアントは必要ありません。
先程のものぐさ海賊パターンと同じクライアントを利用します。
こちらが負荷分散ブローカーと同等の機能を持ったキュープロキシのコードです。

~~~ {caption="spqueue: 単純な海賊ブローカー"}
include(examples/EXAMPLE_LANG/spqueue.EXAMPLE_EXT)
~~~

;Here is the worker, which takes the Lazy Pirate server and adapts it for the load balancing pattern (using the REQ "ready" signaling):

こちらがワーカーのコードです。
ものぐさ海賊パターンのサーバーと同じような仕組みを負荷分散ブローカーに組み込んでいます。

~~~ {caption="spworker: 単純な海賊ワーカー"}
include(examples/EXAMPLE_LANG/spworker.EXAMPLE_EXT)
~~~

;To test this, start a handful of workers, a Lazy Pirate client, and the queue, in any order. You'll see that the workers eventually all crash and burn, and the client retries and then gives up. The queue never stops, and you can restart workers and clients ad nauseam. This model works with any number of clients and workers.

これをテストするには幾つかのワーカーとものぐさ海賊クライアント、およびキュープロキシを起動してやります。順序はなんでも構いません。
そうするとワーカーがクラッシュしたり固まったりするでしょうが、キュープロキシは機能を停止することなく動作し続けます。
このモデルはクライアントやワーカーの数が幾つでも問題なく動作します。

## 頑丈なキューイング (神経質な海賊パターン)

![神経質な海賊パターン](images/fig49.eps)

;The Simple Pirate Queue pattern works pretty well, especially because it's just a combination of two existing patterns. Still, it does have some weaknesses:

単純な海賊パターンはものぐさ海賊パターンと組み合わせて上手く機能する障害対策でしたが、これには欠点があります。

;* It's not robust in the face of a queue crash and restart. The client will recover, but the workers won't. While ØMQ will reconnect workers' sockets automatically, as far as the newly started queue is concerned, the workers haven't signaled ready, so don't exist. To fix this, we have to do heartbeating from queue to worker so that the worker can detect when the queue has gone away.
;* The queue does not detect worker failure, so if a worker dies while idle, the queue can't remove it from its worker queue until the queue sends it a request. The client waits and retries for nothing. It's not a critical problem, but it's not nice. To make this work properly, we do heartbeating from worker to queue, so that the queue can detect a lost worker at any stage.

* キューの再起動やクラッシュに対して堅牢ではありません。またクライアントは自動的に復旧しますがワーカーはそうではありません。ワーカーのØMQソケットは自動的に再接続を行ってくれますが、準備完了メッセージを送信していませんのでメッセージが送られてきません。これを修正するにはキュープロキシからワーカーに対してハートビートを送って、ワーカーの存在を確認する必要があります。
* キュープロキシはワーカーの障害を検知できないため、待機中のワーカーが落ちてしまった場合にワーカーキューから該当のワーカーを削除することが出来ません。存在しないワーカーに対してメッセージを送信すると、クライアントは待たされてしまうでしょう。これは致命的な問題ではありませんが良くもありません。これを上手く動作させるには、ワーカーからキューに対してハートビートを送るワーカーの障害をキューがワーが検知できるようにするよ良いでしょう。

;We'll fix these in a properly pedantic Paranoid Pirate Pattern.

これらの欠点を神経質な海賊パターンで修正します。

;We previously used a REQ socket for the worker. For the Paranoid Pirate worker, we'll switch to a DEALER socket. This has the advantage of letting us send and receive messages at any time, rather than the lock-step send/receive that REQ imposes. The downside of DEALER is that we have to do our own envelope management (re-read Chapter 3 - Advanced Request-Reply Patterns for background on this concept).

これまでのワーカーはREQソケットを利用してきましたが、この神経質な海賊パターンのワーカーはDEALERソケットを利用します。
これにより、送受信の順序に拘らずにいつでもメッセージを送受信出来るというメリットがあります。
デメリットはメッセージエンベロープを管理しなければならない事です。
これについては第3章の「リクエスト・応答パターンの応用」で既に説明しました。

;We're still using the Lazy Pirate client. Here is the Paranoid Pirate queue proxy:

今回もまたものぐさ海賊パターンのクライアントを使いまわします。
こちらは神経質な海賊キュープロキシです。

~~~ {caption="ppqueue: 神経質な海賊キュー"}
include(examples/EXAMPLE_LANG/ppqueue.EXAMPLE_EXT)
~~~

;The queue extends the load balancing pattern with heartbeating of workers. Heartbeating is one of those "simple" things that can be difficult to get right. I'll explain more about that in a second.

このキュープロキシは負荷分散パターンを拡張してワーカーに対してハートビートを送信しています。
ハートビートは単純な機能ですが、正しくこれを行うのは難しいので後ほど詳しく説明します。

;Here is the Paranoid Pirate worker:

以下は神経質な海賊パターンのワーカーです。

~~~ {caption="ppworker: 神経質な海賊ワーカー"}
include(examples/EXAMPLE_LANG/ppworker.EXAMPLE_EXT)
~~~

;Some comments about this example:

このコードを解説すると、

;* The code includes simulation of failures, as before. This makes it (a) very hard to debug, and (b) dangerous to reuse. When you want to debug this, disable the failure simulation.
;* The worker uses a reconnect strategy similar to the one we designed for the Lazy Pirate client, with two major differences: (a) it does an exponential back-off, and (b) it retries indefinitely (whereas the client retries a few times before reporting a failure).

* このコードは以前と同じく、障害をシミュレートするコードが入っています。
* このワーカーはものぐさ海賊パターンのクライアントと同様に再試行を行う戦略です。再試行の間隔を指数的に増やしていき何度でも再試行を行います。

;Try the client, queue, and workers, such as by using a script like this:

以下のスクリプトでこれらのコードを実行してみてください。

~~~
ppqueue &
for i in 1 2 3 4; do
    ppworker &
    sleep 1
done
lpclient &
~~~

;You should see the workers die one-by-one as they simulate a crash, and the client eventually give up. You can stop and restart the queue and both client and workers will reconnect and carry on. And no matter what you do to queues and workers, the client will never get an out-of-order reply: the whole chain either works, or the client abandons.

これを実行すると、ワーカーがひとつずつクラッシュして終了していくことを確認できるでしょう。
キュープロキシを再起動した場合でもワーカーは再接続して動作を継続し、ワーカーが1つでも動いていればクライアントは正しい応答を受け取る事が出来るでしょう。

## ハートビート
;Heartbeating solves the problem of knowing whether a peer is alive or dead. This is not an issue specific to ØMQ. TCP has a long timeout (30 minutes or so), that means that it can be impossible to know whether a peer has died, been disconnected, or gone on a weekend to Prague with a case of vodka, a redhead, and a large expense account.

ハートビートは相手が生きているか死んでいるかを知るための手段です。
これはØMQ固有の概念ではありません。
TCPのタイムアウト時間は約非常に長く、大抵30分程度が設定されています。
これでは相手が生きているのか死んでいのるか、それともプラハに行って酒を飲んでいるか判断することは出来ません。

;It's is not easy to get heartbeating right. When writing the Paranoid Pirate examples, it took about five hours to get the heartbeating working properly. The rest of the request-reply chain took perhaps ten minutes. It is especially easy to create "false failures", i.e., when peers decide that they are disconnected because the heartbeats aren't sent properly.

ハートビートを正しく実装するのは簡単なことではありません。
神経質な海賊パターンのコードではリクエスト・応答のロジックは10分程度で実装できましたがハートビートを正しく動作させるためには5時間程度掛かりました。
;[TODO]

;We'll look at the three main answers people use for heartbeating with ØMQ.

それでは、ØMQの利用者がハートビートを実装する際に直面する3つの問題を見て行きましょう。

### Shrugging It Off
;The most common approach is to do no heartbeating at all and hope for the best. Many if not most ØMQ applications do this. ØMQ encourages this by hiding peers in many cases. What problems does this approach cause?

ØMQアプリケーションのほとんどはハートビートを行いません。
その場合どの様な問題が起こるでしょうか?

;* When we use a ROUTER socket in an application that tracks peers, as peers disconnect and reconnect, the application will leak memory (resources that the application holds for each peer) and get slower and slower.
;* When we use SUB- or DEALER-based data recipients, we can't tell the difference between good silence (there's no data) and bad silence (the other end died). When a recipient knows the other side died, it can for example switch over to a backup route.
;* If we use a TCP connection that stays silent for a long while, it will, in some networks, just die. Sending something (technically, a "keep-alive" more than a heartbeat), will keep the network alive.

* アプリケーションがROUTERソケットを利用して接続を中継している場合、接続と切断を繰り返す度にメモリリークが発生します。そしてだんだん遅くなっていくでしょう。
* SUBソケットやDEALERソケットを利用してメッセージを受信する側は、データが送られてこない事が正常なのか異常なのかを判断することが出来ません。接続相手の異常を検知できれば別の相手に切り替えることが出来ます。
* TCPで接続している場合、長い時間無通信が続くと接続が切られてしまう場合があります。この問題を避けるには「keep-alive」データを送信することで接続を継続することが出来ます。

### 片側ハートビート
;A second option is to send a heartbeat message from each node to its peers every second or so. When one node hears nothing from another within some timeout (several seconds, typically), it will treat that peer as dead. Sounds good, right? Sadly, no. This works in some cases but has nasty edge cases in others.

2番目の選択肢は片方のノードからもう片方のノードへ1秒に1回位の間隔でハートビートを送る方法です。
応答が返らずにタイムアウトが発生した場合(一般的に数秒間)、その相手は落ちたと見なします。
これで本当に良いのでしょうか?
これは上手く動作することもありますが、うまく行かない場合もあります。

;For pub-sub, this does work, and it's the only model you can use. SUB sockets cannot talk back to PUB sockets, but PUB sockets can happily send "I'm alive" messages to their subscribers.

pub-subパターンではこの方法が使える唯一の方法です。
SUBソケットはPUBソケットに対して話しかけることは出来きません、一方、PUBソケットはサブスクライバーに対して「私は生きています」というメッセージを送信できます。

;As an optimization, you can send heartbeats only when there is no real data to send. Furthermore, you can send heartbeats progressively slower and slower, if network activity is an issue (e.g., on mobile networks where activity drains the battery). As long as the recipient can detect a failure (sharp stop in activity), that's fine.

無駄をなくす為には、実際に送信すべきデータがない場合のみハートビートを送信すると良いでしょう。
また、ネットワークが貧弱な場合(例えばモバイルネットワークでバッテリーを節約したい場合)はハートビートの間隔を出来るだけ遅くするのが良いでしょう。
サブスクライバーが障害を検知できさえすれば良いのです。

;Here are the typical problems with this design:

この設計の問題点を挙げると、

;* It can be inaccurate when we send large amounts of data, as heartbeats will be delayed behind that data. If heartbeats are delayed, you can get false timeouts and disconnections due to network congestion. Thus, always treat any incoming data as a heartbeat, whether or not the sender optimizes out heartbeats.
;* While the pub-sub pattern will drop messages for disappeared recipients, PUSH and DEALER sockets will queue them. So if you send heartbeats to a dead peer and it comes back, it will get all the heartbeats you sent, which can be thousands. Whoa, whoa!
;* This design assumes that heartbeat timeouts are the same across the whole network. But that won't be accurate. Some peers will want very aggressive heartbeating in order to detect faults rapidly. And some will want very relaxed heartbeating, in order to let sleeping networks lie and save power.

* 大量のデータが送信されている場合ハートビートのデータが遅延してしまい、不正確になる可能性があります。ハートビートが遅延してしまうとタイムアウトが発生して接続が切れてしまいます。従って受信者はハートビートを受信するかどうかに関わらず、全てのデータをハートビートとして扱う必要があります。
* 受信者が居なくなった場合、PUSHソケットやDEALERソケットであれば送信キューにキューイングされるのですが、pub-subパターンの場合はメッセージを喪失してしまいます。ですのでハートビートの送出間隔以内に受信者が再起動を行った場合、ハートビートは全て受け取っていますが、メッセージは取りこぼしている可能性があります。
* この設計ではハートビートのタイムアウト時間は全て同じである事を前提にしています。しかしそれでは困る場合があります。素早く障害を検知したいノードに対しては積極的なハートビートを行い、電力消費を抑えたいノードに対しては控えめなハートビートを行いたいという事もあるでしょう。

### PING-PONGハートビート
;The third option is to use a ping-pong dialog. One peer sends a ping command to the other, which replies with a pong command. Neither command has any payload. Pings and pongs are not correlated. Because the roles of "client" and "server" are arbitrary in some networks, we usually specify that either peer can in fact send a ping and expect a pong in response. However, because the timeouts depend on network topologies known best to dynamic clients, it is usually the client that pings the server.

3番目の方法はピンポンのやりとりを行うことです。
一方がPINGコマンドを送信し、受信者はPONGコマンドを返信します。
2つのコマンドの相関性を確認するために、両方のコマンドはデータ部を持っています。
ノードは「クライアント」とか「サーバー」といった役割を持っているかもしれませんが、基本的にどちらがPINGを送信して、どちらがPONGを応答するかは任意です。
しかしながらタイムアウトはネットワークのトポロジーに依存していますので、動的なクライアントがPINGを行い、サーバーがPONGを返すのが適切でしょう。

;This works for all ROUTER-based brokers. The same optimizations we used in the second model make this work even better: treat any incoming data as a pong, and only send a ping when not otherwise sending data.

これはROUTERソケットを使ったブローカーで上手く動作します。
2番目の方法で紹介した最適化はここでも有効です。
送信者は実際に送信すべきデータがない場合のみPINGを送信し、受信者は全てのデータをPONGとして扱う事です。

### 神経質な海賊パターンでのハートビート
;For Paranoid Pirate, we chose the second approach. It might not have been the simplest option: if designing this today, I'd probably try a ping-pong approach instead. However the principles are similar. The heartbeat messages flow asynchronously in both directions, and either peer can decide the other is "dead" and stop talking to it.

先ほど説明した神経質な海賊パターンでは2番目の方法でハートビートを行いました。
これは単純ではありますが、今となってはPING-PONGハートビートを使ったほうが良いでしょう。
基本的な所は前と同じです。双方向にハートビートメッセージを非同期で送信し、お互いに相手が落ちているかどうか確認することが出来ます。

;In the worker, this is how we handle heartbeats from the queue:

キューブローカーからのハートビートをワーカーが処理するには、

;* We calculate a liveness, which is how many heartbeats we can still miss before deciding the queue is dead. It starts at three and we decrement it each time we miss a heartbeat.
;* We wait, in the zmq_poll loop, for one second each time, which is our heartbeat interval.
;* If there's any message from the queue during that time, we reset our liveness to three.
;* If there's no message during that time, we count down our liveness.
;* If the liveness reaches zero, we consider the queue dead.
;* If the queue is dead, we destroy our socket, create a new one, and reconnect.
;* To avoid opening and closing too many sockets, we wait for a certain interval before reconnecting, and we double the interval each time until it reaches 32 seconds.

* ハートビートのタイムアウトが何回発生したら相手が落ちたと判断するかという基準(liveness)を決定します。ここでは3回を設定します。
* `zmq_poll`ループではハートビートの間隔の1秒間ブロックしてメッセージを待ちます。
* ハートビートに限らず、何らかのメッセージが届いたら`liveness`を3にリセットします。
* メッセージが届かずタイムアウトした場合に`liveness`をカウントダウンします。
* `liveness`が0になった時、キューブローカーに障害が発生したと判断します。
* 障害を検知したらソケットを破棄し、再接続を試みます。
* 大量のソケットが再接続を繰り返すのを避けるためにsleepを行っています。これは再接続の度に2倍され、最大32秒まで増えます。

;And this is how we handle heartbeats to the queue:

そしてキューブローカーがハートビートを処理する流れは以下の通りです。

;* We calculate when to send the next heartbeat; this is a single variable because we're talking to one peer, the queue.
;* In the zmq_poll loop, whenever we pass this time, we send a heartbeat to the queue.

* 次のハートビートを送信する時間を決定します。これは通信相手が1つの場合は単一の変数です。
* `zmq_poll`ループの中でこの時間を経過した場合にハートビートを送信します。

;Here's the essential heartbeating code for the worker:

こちらがワーカーがハートビートを行う主要なコードです。

~~~
#define HEARTBEAT_LIVENESS 3 // 3-5 is reasonable
#define HEARTBEAT_INTERVAL 1000 // msecs
#define INTERVAL_INIT 1000 // Initial reconnect
#define INTERVAL_MAX 32000 // After exponential backoff

…
// If liveness hits zero, queue is considered disconnected
size_t liveness = HEARTBEAT_LIVENESS;
size_t interval = INTERVAL_INIT;

// Send out heartbeats at regular intervals
uint64_t heartbeat_at = zclock_time () + HEARTBEAT_INTERVAL;

while (true) {
    zmq_pollitem_t items [] = { { worker, 0, ZMQ_POLLIN, 0 } };
    int rc = zmq_poll (items, 1, HEARTBEAT_INTERVAL * ZMQ_POLL_MSEC);

    if (items [0].revents & ZMQ_POLLIN) {
        // Receive any message from queue
        liveness = HEARTBEAT_LIVENESS;
        interval = INTERVAL_INIT;
    }
    else
    if (--liveness == 0) {
        zclock_sleep (interval);
        if (interval < INTERVAL_MAX)
            interval *= 2;
        zsocket_destroy (ctx, worker);
        …
        liveness = HEARTBEAT_LIVENESS;
    }
    // Send heartbeat to queue if it's time
    if (zclock_time () > heartbeat_at) {
        heartbeat_at = zclock_time () + HEARTBEAT_INTERVAL;
        // Send heartbeat message to queue
    }
}
~~~

;The queue does the same, but manages an expiration time for each worker.
キューブローカー側もだいたい同じですがワーカー毎に有効時間を管理する必要があります。

;Here are some tips for your own heartbeating implementation:

以下はハートビートを実装する上でのアドバイスです。

;* Use zmq_poll or a reactor as the core of your application's main task.
;* Start by building the heartbeating between peers, test it by simulating failures, and then build the rest of the message flow. Adding heartbeating afterwards is much trickier.
;* Use simple tracing, i.e., print to console, to get this working. To help you trace the flow of messages between peers, use a dump method such as zmsg offers, and number your messages incrementally so you can see if there are gaps.
;* In a real application, heartbeating must be configurable and usually negotiated with the peer. Some peers will want aggressive heartbeating, as low as 10 msecs. Other peers will be far away and want heartbeating as high as 30 seconds.
;* If you have different heartbeat intervals for different peers, your poll timeout should be the lowest (shortest time) of these. Do not use an infinite timeout.
;* Do heartbeating on the same socket you use for messages, so your heartbeats also act as a keep-alive to stop the network connection from going stale (some firewalls can be unkind to silent connections).

* アプリケーションのメインループでは、`zmq_poll`かリアクターを使用して下さい。
* ハートビートを実装できたら、まず障害をシミュレートしてテストしてください。そしてその他のメッセージ処理を実装するのが良いでしょう。後からハートビートを実装するのは非常に難い事です。
* ターミナルに出力するなどして簡単に動作確認してください。メッセージの流れを追うには、zmsgが提供するdump関数が役立ちます。これで想定通りのメッセージが流れているか確認しましょう。
* 実際のアプリケーションではハートビート間隔は設定で記述するか、ネゴシエートすべきでしょう。特定の接続相手には10ミリ秒程度の積極的なハートビートを行いたい事もあるでしょうし、30秒程度の長い間隔で行いたい事もあります。
* ハートビート間隔が接続相手毎に異なる場合、`zmq_poll`のポーリング間隔はこれらの中で最短の間隔である必要があります。また、無限のタイムアウトを設定してはいけません。
* 実際のデータ通信と同じソケットでハートビート行って下さい。ハートービートはネットワークコネクションを維持するためのキープアライブとしての役割もあります。(不親切なルーターは通信が行われていない接続を切ってしまう事があるからです)

## 規約とプロトコル
;If you're paying attention, you'll realize that Paranoid Pirate is not interoperable with Simple Pirate, because of the heartbeats. But how do we define "interoperable"? To guarantee interoperability, we need a kind of contract, an agreement that lets different teams in different times and places write code that is guaranteed to work together. We call this a "protocol".

ここまで注意深く読んできた読者は、神経質な海賊パターンと単純な海賊パターンを相互運用できないことに気がついたでしょう。
しかし「相互運用」とはどの様なものでしょうか?
相互運用を保証するためには、異なる時間や場所で動作しているコードが協調して動作するための規約に同意する必要があります。
これを私達は「プロトコル」と呼びます。

;It's fun to experiment without specifications, but that's not a sensible basis for real applications. What happens if we want to write a worker in another language? Do we have to read code to see how things work? What if we want to change the protocol for some reason? Even a simple protocol will, if it's successful, evolve and become more complex.

仕様の無いプロトコルで実験することは楽しいことですが、実際のアプリケーションでこれを行うのは賢明な判断とは言えません。
例えばワーカーを別のプログラミング言語で書きたい場合はどうしますか?
コードを読んで動作を調べますか?
プロトコルを変更したい時はどうしますか?
元々は単純なプロトコルであっても、プロトコルが普及するに従って進化し、複雑になっていきます。

;Lack of contracts is a sure sign of a disposable application. So let's write a contract for this protocol. How do we do that?

規約の欠如はアプリケーションが使い捨てにされる兆候です。
というわけでプロトコルとしての規約を書いてみましょう。

;There's a wiki at rfc.zeromq.org that we made especially as a home for public ØMQ contracts.
;To create a new specification, register on the wiki if needed, and follow the instructions. It's fairly straightforward, though writing technical texts is not everyone's cup of tea.

公開されたØMQの規約を集めた[rfc.zeromq.org](http://rfc.zeromq.org/)というWikiサイトがあります。
新しい仕様を作成するには、wikiのアカウントを登録して書かれている手順に従って下さい。
技術文書を書くのが得意ではない方もいると思いますが、これはとっても簡単な事ですよ。

;It took me about fifteen minutes to draft the new Pirate Pattern Protocol. It's not a big specification, but it does capture enough to act as the basis for arguments ("your queue isn't PPP compatible; please fix it!").

海賊パターンの仕様を書くのに15分程度掛かりました。
これは大きな仕様ではありませんが、基本的な振る舞いを理解するためには十分です。
このキューは神経質な海賊パターンと互換性がありませんので必要に応じて修正して下さい。

;Turning PPP into a real protocol would take more work:

実際の神経質な海賊パターンは以下のように動作します。

;* There should be a protocol version number in the READY command so that it's possible to distinguish between different versions of PPP.
;* Right now, READY and HEARTBEAT are not entirely distinct from requests and replies. To make them distinct, we would need a message structure that includes a "message type" part.

* プロトコルバージョンを区別できるように、READYコマンドでプロトコルバージョンを通知すべきでしょう。
* すでに、READYとハートビートコマンドというまったく異なるメッセージ種別が存在します。これらを区別するためにメッセージ構造に「メッセージ種別」を含める必要があるでしょう。

## 信頼性のあるサービス試行キューイング(Majordomoパターン)

![Majordomoパターン](images/fig50.eps)

;The nice thing about progress is how fast it happens when lawyers and committees aren't involved. The one-page MDP specification turns PPP into something more solid. This is how we should design complex architectures: start by writing down the contracts, and only then write software to implement them.

;[TODO]
Majordomopプロトコルには信頼性を高める効果もあります。
この様な複雑なアーキテクチャを実装するには、まずプロトコル仕様書を書く必要があります。

;The Majordomo Protocol (MDP) extends and improves on PPP in one interesting way: it adds a "service name" to requests that the client sends, and asks workers to register for specific services. Adding service names turns our Paranoid Pirate queue into a service-oriented broker. The nice thing about MDP is that it came out of working code, a simpler ancestor protocol (PPP), and a precise set of improvements that each solved a clear problem. This made it easy to draft.

Majordomoプロトコルは面白い方法で神経質な海賊パターンを拡張します。
クライアントが送信するリクエストに「サービス名」を付加し、特定のサービスに登録されたワーカーに振り分けられます。
神経質な海賊キューにサービス名を追加するとサービス指向ブローカーになります。
このパターンの良い所は、単純なプロトコル(神経質な海賊パターン)を元にしているため既存の問題が既に解決されていることと、実際に動作するコードが公開されていることです。
この仕様は簡単に書くことが出来ました。

;To implement Majordomo, we need to write a framework for clients and workers. It's really not sane to ask every application developer to read the spec and make it work, when they could be using a simpler API that does the work for them.

Majordomoプロトコルを実装するには、クライアントとワーカーのフレームワークを用意する必要があるります。
全てのアプリケーション開発者がプロトコル仕様書を読んで理解するのは難しいことですから簡単に利用できるAPIを用意するのが良いでしょう。

;So while our first contract (MDP itself) defines how the pieces of our distributed architecture talk to each other, our second contract defines how user applications talk to the technical framework we're going to design.

1つ目の仕様書では、分散アーキテクチャーの部品同士が通信を行う方法を定義します。
そして2つ目の仕様書ではユーザーアプリケーションがこれらのフレームワークと通信する方法を定義します。

;Majordomo has two halves, a client side and a worker side. Because we'll write both client and worker applications, we will need two APIs. Here is a sketch for the client API, using a simple object-oriented approach:

Majordomoプロトコルはクライアント側とワーカー側の2種類に分かれますので2つのAPIが必要です。
こちらは単純なオブジェクト指向を利用して設計したクライアント側のAPIです。

~~~
mdcli_t *mdcli_new     (char *broker);
void     mdcli_destroy (mdcli_t **self_p);
zmsg_t  *mdcli_send    (mdcli_t *self, char *service, zmsg_t **request_p);
~~~

;That's it. We open a session to the broker, send a request message, get a reply message back, and eventually close the connection. Here's a sketch for the worker API:

これだけです。
ブローカとのセッションを張り、リクエストを送信して応答を受け取って接続を切っています。
こちらはワーカー側のAPIです。

~~~
mdwrk_t *mdwrk_new     (char *broker,char *service);
void     mdwrk_destroy (mdwrk_t **self_p);
zmsg_t  *mdwrk_recv    (mdwrk_t *self, zmsg_t *reply);
~~~

;It's more or less symmetrical, but the worker dialog is a little different. The first time a worker does a recv(), it passes a null reply. Thereafter, it passes the current reply, and gets a new request.

これは対称的なコードに見えるかもしれませんが、ワーカー側のやりとりにちょっとした違いがあります。
初回のrecv()呼び出しではnullを受け取り、続いてリクエストを受信します。

The client and worker APIs were fairly simple to construct because they're heavily based on the Paranoid Pirate code we already developed. Here is the client API:
クライアントとワーカーは既に実装済みの神経質な海賊パターンのコードを流用する事で、今回のAPIはとても簡単に設計することができました。

~~~ {caption="mdcliapi: MajordomoクライアントAPI"}
include(examples/EXAMPLE_LANG/mdcliapi.EXAMPLE_EXT)
~~~

;Let's see how the client API looks in action, with an example test program that does 100K request-reply cycles:

それではクライアントAPIを動かしてみましょう。
こちらは10万回のリクエスト・応答のサイクルを実行するテストコードです。

~~~ {caption="mdclient: Majordomoクライアントアプリケーション"}
include(examples/EXAMPLE_LANG/mdclient.EXAMPLE_EXT)
~~~

;And here is the worker API:

そしてこちらはワーカーのAPIです。

~~~ {caption="mdwrkapi: MajordomoワーカーAPI"}
include(examples/EXAMPLE_LANG/mdwrkapi.EXAMPLE_EXT)
~~~

;Let's see how the worker API looks in action, with an example test program that implements an echo service:


ワーカーのAPIを用いてechoサービスを実装するテストコードを見て見ましょう。

~~~ {caption="mdworker: Majordomoワーカーアプリケーション"}
include(examples/EXAMPLE_LANG/mdworker.EXAMPLE_EXT)
~~~

;Here are some things to note about the worker API code:

ワーカーAPIについて注意すべき点を挙げます。

;* The APIs are single-threaded. This means, for example, that the worker won't send heartbeats in the background. Happily, this is exactly what we want: if the worker application gets stuck, heartbeats will stop and the broker will stop sending requests to the worker.
;* The worker API doesn't do an exponential back-off; it's not worth the extra complexity.
;* The APIs don't do any error reporting. If something isn't as expected, they raise an assertion (or exception depending on the language). This is ideal for a reference implementation, so any protocol errors show immediately. For real applications, the API should be robust against invalid messages.

* このAPIはシングルスレッドで動作します。つまりバックグラウンドスレッドでハートビートを送信するような事はしていません。
* このAPIは指数的な間隔で再試行を行いません。
* このAPIはエラー報告を行いません。必要に応じてアサーションや例外を投げたりすると良いでしょう。これは仮の参照実装ですので実際のアプリケーションでは不正なメッセージに対して堅牢でなくてはなりません。

;You might wonder why the worker API is manually closing its socket and opening a new one, when ØMQ will automatically reconnect a socket if the peer disappears and comes back. Look back at the Simple Pirate and Paranoid Pirate workers to understand. Although ØMQ will automatically reconnect workers if the broker dies and comes back up, this isn't sufficient to re-register the workers with the broker. I know of at least two solutions. The simplest, which we use here, is for the worker to monitor the connection using heartbeats, and if it decides the broker is dead, to close its socket and start afresh with a new socket. The alternative is for the broker to challenge unknown workers when it gets a heartbeat from the worker and ask them to re-register. That would require protocol support.

ØMQは通信相手が落ちた場合に自動的に再接続を行うにも関わらず、ワーカーAPIでソケットを手動で閉じて再接続している事を不思議に思うかもしれません。
単純な海賊パターンや神経質な海賊ワーカーを振り返って見てもらえると解ると思いますが、ワーカーはブローカーが落ちた際に再接続を行いますがこれだけでは十分ではありません。
これには2つの解決方法があります。
ワーカーはハートビートを利用してブローカーが落ちたことを検知すると、ソケットを閉じて新しいソケットで再接続を行います。
もうひとつの方法は、未知のブローカーからハートビートを受け取った場合に再登録を行うようにする事です。
すなわちプロトコルでの対応が必要になります。

;Now let's design the Majordomo broker. Its core structure is a set of queues, one per service. We will create these queues as workers appear (we could delete them as workers disappear, but forget that for now because it gets complex). Additionally, we keep a queue of workers per service.

それではMajordomoブローカーを設計してみましょう。
基本的な構造としてサービス毎にひとつのキューを持っていて、このキューはワーカーが接続した時に生成されます。

;And here is the broker:

こちらがブローカーのコードです。

~~~{caption="mdbroker: Majordomoブローカー"}
include(examples/EXAMPLE_LANG/mdbroker.EXAMPLE_EXT)
~~~

;This is by far the most complex example we've seen. It's almost 500 lines of code. To write this and make it somewhat robust took two days. However, this is still a short piece of code for a full service-oriented broker.

このサンプルコードはこれまで見てきた中で最も複雑な例でしょう。
約500行もあり、これをちゃんと動作させるために2日もかかりました。
しかし、完全なサービス指向ブローカーとしては短い方です。

;Here are some things to note about the broker code:

このブローカー注意点は、

;* The Majordomo Protocol lets us handle both clients and workers on a single socket. This is nicer for those deploying and managing the broker: it just sits on one ØMQ endpoint rather than the two that most proxies need.
;* The broker implements all of MDP/0.1 properly (as far as I know), including disconnection if the broker sends invalid commands, heartbeating, and the rest.
;* It can be extended to run multiple threads, each managing one socket and one set of clients and workers. This could be interesting for segmenting large architectures. The C code is already organized around a broker class to make this trivial.
;* A primary/failover or live/live broker reliability model is easy, as the broker essentially has no state except service presence. It's up to clients and workers to choose another broker if their first choice isn't up and running.
;* The examples use five-second heartbeats, mainly to reduce the amount of output when you enable tracing. Realistic values would be lower for most LAN applications. However, any retry has to be slow enough to allow for a service to restart, say 10 seconds at least.

* Majordomoブローカーはワーカーとクライアントの両方からの接続を1つのソケットで受け付けます。エンドポイントが2つあるより1つの方が管理上便利でしょう。
* このブローカーはハートビートや不正なコマンドの処理など、MDP/0.1の仕様が全て実装されています。
* アーキテクチャが大規模になる場合、クライアントとワーカーの組み合わせに対してひとつのスレッドが対応するような、マルチスレッドに拡張することも可能です。これによりとても大規模なアーキテクチャを構築できます。
* ブローカーは状態を持たないのでプライマリー／バックアップ、あるいはプライマリー／プライマリーという信頼性モデルの構築は簡単です。最初にどちらのブローカーに接続するかはクライアントやワーカー次第です。
* このサンプルコードでは動作を確認しやすい様に、ハートビートを5秒間の間隔で行っています。実際のアプリケーションではもっと短い間隔の方が良いでしょうが、サービスを再起動する場合を考えて、再試行間隔は10秒以上にした方が良いでしょう。

;We later improved and extended the protocol and the Majordomo implementation, which now sits in its own Github project. If you want a properly usable Majordomo stack, use the GitHub project.

後に私達はこのMajordomoプロトコルの拡張と改良を行い、GitHubプロジェクトで公開しました。
ちゃんとしたMajordomoスタックを利用したい場合はGitHubプロジェクトを見て下さい。

## 非同期のMajordomoパターン
;The Majordomo implementation in the previous section is simple and stupid. The client is just the original Simple Pirate, wrapped up in a sexy API. When I fire up a client, broker, and worker on a test box, it can process 100,000 requests in about 14 seconds. That is partially due to the code, which cheerfully copies message frames around as if CPU cycles were free. But the real problem is that we're doing network round-trips. ØMQ disables Nagle's algorithm, but round-tripping is still slow.

前節では愚直なMajordomoの実装を紹介しました。
クライアントは単純な海賊モデルをセクシーなAPIでラップしただけのものです。
クライアントとブローカーとワーカーを1台のサーバーで稼働させると14秒間の間に10万リクエスト処理できるはずです。すなわちCPUリソースのある限りメッセージフレームをコピー出来るという事です。しかし現実的にはネットワークのラウンドトリップが問題になります。ØMQはNagleのアルゴリズムを無効にしており、ラウンドトリップは非常に遅いものなのです。

;Theory is great in theory, but in practice, practice is better. Let's measure the actual cost of round-tripping with a simple test program. This sends a bunch of messages, first waiting for a reply to each message, and second as a batch, reading all the replies back as a batch. Both approaches do the same work, but they give very different results. We mock up a client, broker, and worker:

理論は理論として素晴らしいものですが、実践には実践の良さがあります。
簡単なテストプログラムを作成して実際のラウンドトリップを計測してみましょう。

1つ目のテストは大量のメッセージをひとつずつ送信と受信を繰り返します。
もうひとつのテストは、まず大量のメッセージを送信して、あとから全ての応答を受信します。
両方のテストは同じことを行っていますが、異なるテスト結果が得られるでしょう。
テストコードは以下の通りです。

~~~ {caption="tripping: ラウンド・トリップの計測"}
include(examples/EXAMPLE_LANG/tripping.EXAMPLE_EXT)
~~~

;On my development box, this program says:

私の開発サーバーでは以下の結果が得られました。

~~~
Setting up test...
Synchronous round-trip test...
 9057 calls/second
Asynchronous round-trip test...
 173010 calls/second
~~~

;Note that the client thread does a small pause before starting. This is to get around one of the "features" of the router socket: if you send a message with the address of a peer that's not yet connected, the message gets discarded. In this example we don't use the load balancing mechanism, so without the sleep, if the worker thread is too slow to connect, it will lose messages, making a mess of our test.

クライアントは計測を開始する前に少しだけsleepする必要があることに注意して下さい。
ルーティング先が存在しない場合はROUTERソケットはメッセージを捨てるという「機能」があるからです。
この例では負荷分散パターンを使用していませんので、sleepを入れないとワーカーの接続に時間がかかってしまった場合にメッセージが失われてしまいます。
これでは計測のテストになりません。

;As we see, round-tripping in the simplest case is 20 times slower than the asynchronous, "shove it down the pipe as fast as it'll go" approach. Let's see if we can apply this to Majordomo to make it faster.

ご覧の通り、1つ目のテストは2番目の非同期のテストよりもランドトリップの影響で20倍程度遅い事が判ります。
それではこの非同期の実装をMajordomoパターンに適用してみましょう。

;First, we modify the client API to send and receive in two separate methods:

まず、APIを送信と受信の2つの関数に別けます。

~~~
mdcli_t *mdcli_new (char *broker);
void mdcli_destroy (mdcli_t **self_p);
int mdcli_send (mdcli_t *self, char *service, zmsg_t **request_p);
zmsg_t *mdcli_recv (mdcli_t *self);
~~~

;It's literally a few minutes' work to refactor the synchronous client API to become asynchronous:

ほんの数分の手間で同期式クライアントを非同期に書き換えることが出来ました。

~~~{caption="mdcliapi2: Majordomo非同期クライアントAPI"}
include(examples/EXAMPLE_LANG/mdcliapi2.EXAMPLE_EXT)
~~~

;The differences are:

変更点は、

;* We use a DEALER socket instead of REQ, so we emulate REQ with an empty delimiter frame before each request and each response.
;* We don't retry requests; if the application needs to retry, it can do this itself.
;* We break the synchronous send method into separate send and recv methods.
;* The send method is asynchronous and returns immediately after sending. The caller can thus send a number of messages before getting a response.
;* The recv method waits for (with a timeout) one response and returns that to the caller.

* REQソケットの代わりにDEALERソケットに置き換えましたのでエンベロープ意識する必要があります。
* APIの中でリクエストの再試行を行いません。必要に応じてアプリケーション内で再試行を行って下さい。
* 同期的な送受信のAPIを廃止して、送信と受信の関数に別けました。
* send関数は非同期ですので呼び出し後直ぐに戻ってきます。
* recv関数はタイムアウト付きでブロックし、メッセージを受信すると呼び出しに戻ります。

;And here's the corresponding client test program, which sends 100,000 messages and then receives 100,000 back:

そして10万メッセージを送信した後に10万メッセージを受信するテストプログラムをこのAPIを使って書き直すと以下のようになります。

~~~{caption="mdclient2: Majordomo非同期クライアントアプリケーション"}
include(examples/EXAMPLE_LANG/mdclient2.EXAMPLE_EXT)
~~~

;The broker and worker are unchanged because we've not modified the protocol at all. We see an immediate improvement in performance. Here's the synchronous client chugging through 100K request-reply cycles:

プロトコル自体を変更した訳ではありませんので、ブローカーとワーカーのコードに変更はありません。
それではパフォーマンスがどれだけ改善したか見てみましょう。
以下は同期的クライアントでに一気に10万リクエストの送受信を行った際の実行結果です。

~~~
$ time mdclient
100000 requests/replies processed

real    0m14.088s
user    0m1.310s
sys     0m2.670s
~~~

;And here's the asynchronous client, with a single worker:

そして、こちらが非同期クライアントで1つのワーカーにリクエストを行った際の実行結果です。

~~~
$ time mdclient2
100000 replies received

real    0m8.730s
user    0m0.920s
sys     0m1.550s
~~~

;Twice as fast. Not bad, but let's fire up 10 workers and see how it handles the traffic

2倍早くなりました、悪くありませんがワーカーを10に増やしてみましょう。

~~~
$ time mdclient2
100000 replies received

real    0m3.863s
user    0m0.730s
sys     0m0.470s
~~~

;It isn't fully asynchronous because workers get their messages on a strict last-used basis. But it will scale better with more workers. On my PC, after eight or so workers, it doesn't get any faster. Four cores only stretches so far. But we got a 4x improvement in throughput with just a few minutes' work. The broker is still unoptimized. It spends most of its time copying message frames around, instead of doing zero-copy, which it could. But we're getting 25K reliable request/reply calls a second, with pretty low effort.

ワーカーは受け取ったメッセージを順番に処理しているのでこれは完全な非同期とは言えませんが、これはワーカーを増やすことで解決できます。
私のPCは4Coreしか無いのでワーカーを8個以上に増やしてもそれ以上早くなりませんでした。
しかし、まだブローカーについては最適化を行っていないにも関わらず、たった数分間の工夫で4倍ものパフォーマンスの向上が得られたのです。
処理の大半はメッセージのコピーに費やされているので、ゼロコピーを行うことで更に早くなる余地があります。
さして労力をかけずに2.5万回のリクエスト・応答を処理できればまあ十分でしょう。

;However, the asynchronous Majordomo pattern isn't all roses. It has a fundamental weakness, namely that it cannot survive a broker crash without more work. If you look at the mdcliapi2 code you'll see it does not attempt to reconnect after a failure. A proper reconnect would require the following:

ところで、非同期のMajordomoパターンに欠点が無いわけではありません。
これにはブローカーのクラッシュから回復できないという根本的な欠点があります。
mdcliapi2のコードを読むと再接続を行っていない事が分かるでしょう。
正しく再接続を行うには以下のことを行う必要があります。

;* A number on every request and a matching number on every reply, which would ideally require a change to the protocol to enforce.
;* Tracking and holding onto all outstanding requests in the client API, i.e., those for which no reply has yet been received.
;* In case of failover, for the client API to resend all outstanding requests to the broker.

* 全てのリクエストに番号を振り、応答と照合します。これにはプロトコルの変更が必要です。
* 送信する全てのリクエストをクライアントAPIでトラッキングし、受信していない応答を把握する必要があります。
* フェイルオーバーが発生した場合はまだ応答が返ってきていないリクエストをブローカーに再送します。

;It's not a deal breaker, but it does show that performance often means complexity. Is this worth doing for Majordomo? It depends on your use case. For a name lookup service you call once per session, no. For a web frontend serving thousands of clients, probably yes.

これらは無理なことではありませんが、確実に複雑性が増えます。
これが本当にMajordomoに必要かどうかは用途に依存するでしょう。
数千ものクライアントが接続するWEBフロントエンドでは必要かもしれませんが、DNSの様に1リクエストでセッションが完了する様なサービスでは必要ありません。

## サービスディスカバリー
;So, we have a nice service-oriented broker, but we have no way of knowing whether a particular service is available or not. We know whether a request failed, but we don't know why. It is useful to be able to ask the broker, "is the echo service running?" The most obvious way would be to modify our MDP/Client protocol to add commands to ask this. But MDP/Client has the great charm of being simple. Adding service discovery to it would make it as complex as the MDP/Worker protocol.

素晴らしいサービス指向ブローカーを作ることが出来ましたが、まだサービスが登録済みかどうかを知る方法がありません。
動作していないサービスへのリクエストは失敗しますが、何故失敗したのかが分かりません。
そこで「echoサービスは動作していますか?」という様な問い合わせを行えると便利でしょう。
最も解かりやすい方法はMDPのクライアント側のプロトコルを改修して新しいコマンドを追加することです。
しかしこれではMDPクライアントプロトコルの最大の魅力である単純さが失われてしまいます。

;Another option is to do what email does, and ask that undeliverable requests be returned. This can work well in an asynchronous world, but it also adds complexity. We need ways to distinguish returned requests from replies and to handle these properly.

もうひとつの方法はEメールの様に無効なリクエストを返送することです。
この方法は非同期の世界では上手く動作しますが、応答を受け取る際にどの様な応答かを適切に区別する必要があるため更に複雑性になってしまいます。

;Let's try to use what we've already built, building on top of MDP instead of modifying it. Service discovery is, itself, a service. It might indeed be one of several management services, such as "disable service X", "provide statistics", and so on. What we want is a general, extensible solution that doesn't affect the protocol or existing applications.

という訳で、既に私が用意した、MDPプロトコルを踏襲したサービスディスカバリーを使ってみましょう。
サービスディスカバリーもそれ自体がサービスです。
サービスを無効にしたり、サービスの利用統計提供するなどの管理サービスも必要になる可能性もあるでしょう。
必要なのは、既存のプロトコルやアプリケーションに影響しない一般的で拡張性のあるソリューションです。

;So here's a small RFC that layers this on top of MDP: the Majordomo Management Interface (MMI). We already implemented it in the broker, though unless you read the whole thing you probably missed that. I'll explain how it works in the broker:

ここに[MMI: Majordomo Management Interface](http://rfc.zeromq.org/spec:8)というMDPプロトコルの上レイヤに構築した小さな仕様書があります。
私達は既にこのプロトコルを実装しているのですが、コードをじっくり読んでいないのであれば恐らく見逃しているでしょう。
これがどの様に動作するか説明すると。

;* When a client requests a service that starts with mmi., instead of routing this to a worker, we handle it internally.
;* We handle just one service in this broker, which is mmi.service, the service discovery service.
;* The payload for the request is the name of an external service (a real one, provided by a worker).
;* The broker returns "200" (OK) or "404" (Not found), depending on whether there are workers registered for that service or not.

* クライアントがmmiで始まるサービスに対してリクエストを行うと、ブローカーはワーカーにルーティングせずに内部的に処理します。
* このブローカーが行うサービスのひとつとして、mmi.serviceというサービス名でサービスディスカバリーを提供します。
* リクエストデータは実際に問い合わせを行うサービス名を指定します。
* ブローカーはそれが登録済みのサービスであれば「200」、存在しなければ「404」を返します。

;Here's how we use the service discovery in an application:

以下はアプリケーションの中でサービスディスカバリーを使用する方法です。

~~~{caption="mmiecho: Majordomoでのサービスディスカバリー"}
include(examples/EXAMPLE_LANG/mmiecho.EXAMPLE_EXT)
~~~

;Try this with and without a worker running, and you should see the little program report "200" or "404" accordingly. The implementation of MMI in our example broker is flimsy. For example, if a worker disappears, services remain "present". In practice, a broker should remove services that have no workers after some configurable timeout.

ワーカーを起動していない状態でこのコードを実行すると「404」が返ってくるでしょう。
このMMI実装は手抜きですので、ワーカーが居なくなった場合も登録されたままになってしまいます。
実際には、ワーカーが居なくなって一定のタイムアウトが経過するとサービスを削除する必要があります。

## サービスの冪等性
;Idempotency is not something you take a pill for. What it means is that it's safe to repeat an operation. Checking the clock is idempotent. Lending ones credit card to ones children is not. While many client-to-server use cases are idempotent, some are not. Examples of idempotent use cases include:

冪等性と聞いてなんだか難しいものだと考える必要はありません。
これは単に、何度繰り返し実行しても安全であるという意味です。
時刻の確認は冪等性があります。
クレジットカードを子供に貸す行為には冪等性はありません。
クライアント・サーバーモデルの多くは冪等性がありますが、無いものもあります。
例を挙げると、

;* Stateless task distribution, i.e., a pipeline where the servers are stateless workers that compute a reply based purely on the state provided by a request. In such a case, it's safe (though inefficient) to execute the same request many times.
;* A name service that translates logical addresses into endpoints to bind or connect to. In such a case, it's safe to make the same lookup request many times.

* ステートレスなタスク分散処理には冪等性があります。例えばリクエストの内容のみに基づいてワーカーが計算を行うパイプラインモデルです。この様なケースでは非効率ではありますが、同じリクエストを何度実行しても安全です。
* 論理アドレスからエンドポイントのアドレスに変換する名前解決サービスには冪等性があります。同一の名前解決リクエストを何度行っても安全です。

;And here are examples of a non-idempotent use cases:

冪等性の無いサービスの例を挙げると、

;* A logging service. One does not want the same log information recorded more than once.
;* Any service that has impact on downstream nodes, e.g., sends on information to other nodes. If that service gets the same request more than once, downstream nodes will get duplicate information.
;* Any service that modifies shared data in some non-idempotent way; e.g., a service that debits a bank account is not idempotent without extra work.

* ロギングサービス。同じログの内容が複数記録されていは困ります。
* 下流に影響を与えるサービス。受け取ったメッセージを他のノードに転送するサービスはが同一のメッセージを受け取ると、下流のノードも重複したメッセージを受け取るでしょう。
* 冪等性の無い方法で共有されているデータを更新するサービス。たとえば銀行口座の預金額を変更するサービスは工夫を行わなわない限り冪等性がありません。

;When our server applications are not idempotent, we have to think more carefully about when exactly they might crash. If an application dies when it's idle, or while it's processing a request, that's usually fine. We can use database transactions to make sure a debit and a credit are always done together, if at all. If the server dies while sending its reply, that's a problem, because as far as it's concerned, it has done its work.

アプリケーションに冪等性がない場合はクラッシュした際の対応はより慎重に考えなければなりません。
アプリケーションがリクエストを受け付けていない段階で落ちた場合は特に問題ありませんが、データーベースのトランザクションの様な処理を行うアプリケーションにおいてリクエストの処理中に問題が発生した場合は問題となります。

;If the network dies just as the reply is making its way back to the client, the same problem arises. The client will think the server died and will resend the request, and the server will do the same work twice, which is not what we want.

クライアントに応答を返している最中にネットワーク障害が発生した場合に同じ問題が発生します。
クライアントはサーバーが落ちたのだと思ってリクエストを再送し、サーバーは同じリクエストを2度処理します。
これは望ましい動作ではありません。

;To handle non-idempotent operations, use the fairly standard solution of detecting and rejecting duplicate requests. This means:

非冪等性な操作を行う場合一般的には、重複したリクエストを処理しないような対策を行います。具体的には、

;* The client must stamp every request with a unique client identifier and a unique message number.
;* The server, before sending back a reply, stores it using the combination of client ID and message number as a key.
;* The server, when getting a request from a given client, first checks whether it has a reply for that client ID and message number. If so, it does not process the request, but just resends the reply.

* クライアントは全てのリクエストにユニークなクライアントIDとユニークなメッセージIDを付けて送信します。
* サーバーはリクエストに対して応答する前に、クライアントIDとメッセージIDの組み合わせをキーにして保存します。
* 次にサーバーがリクエストを受け取った際に、まずクライアントIDとメッセージIDの組み合わせを確認して同じリクエストを処理しないようにします。

## 非接続性の信頼性(タイタニックパターン)
;Once you realize that Majordomo is a "reliable" message broker, you might be tempted to add some spinning rust (that is, ferrous-based hard disk platters). After all, this works for all the enterprise messaging systems. It's such a tempting idea that it's a little sad to have to be negative toward it. But brutal cynicism is one of my specialties. So, some reasons you don't want rust-based brokers sitting in the center of your architecture are:

Majordomoが信頼性のあるメッセージブローカーとして機能する事が分かると、次にあなたはハードディスクへの永続化を行いたいと思うかもしれません。
エンタープライズのメッセージングシステムにはそのような機能が用意されています。
これは魅力的なアイディアですが、けして良いことばかりではありません。
皮肉なことにこれは私の専門分野のひとつなのですが、必ずしも永続化が必須ではない幾つかの理由があります。

;* As you've seen, the Lazy Pirate client performs surprisingly well. It works across a whole range of architectures, from direct client-to-server to distributed queue proxies. It does tend to assume that workers are stateless and idempotent. But we can work around that limitation without resorting to rust.
;* Rust brings a whole set of problems, from slow performance to additional pieces that you have to manage, repair, and handle 6 a.m. panics from, as they inevitably break at the start of daily operations. The beauty of the Pirate patterns in general is their simplicity. They won't crash. And if you're still worried about the hardware, you can move to a peer-to-peer pattern that has no broker at all. I'll explain later in this chapter.

* これまで見てきたように、ものぐさ海賊パターンはとてもうまく機能します。異なるアーキテクチャに跨がった分散キュープロキシとして機能し、ワーカーはステートレスで冪等性があるとみなすことができましたが、永続化を行った場合はこうは行きません。
* 永続化はパフォーマンスを低下させ、管理しなければならない新たな部品を増やし、障害が発生すると業務に支障が出ないように朝の6時までに修理しなければなりません。海賊パターンの美しい所は単純な所です。このパターンはクラッシュが発生しません。
もしハードウェア障害を心配しているのであればP2Pパターンに移行してブローカーを無くせば良いでしょう。これについては次の章で説明します。

;Having said this, however, there is one sane use case for rust-based reliability, which is an asynchronous disconnected network. It solves a major problem with Pirate, namely that a client has to wait for an answer in real time. If clients and workers are only sporadically connected (think of email as an analogy), we can't use a stateless network between clients and workers. We have to put state in the middle.

とは言っても、永続化を行い非接続な非同期ネットワークの信頼性を高めるユースケースがひとつだけあります。
これは海賊パターンの一般的な問題を解決します。
クライアントとワーカーが散発的にしか接続しない場合(Eメールの様なシステムを思い浮かべて下さい)はステートレスなネットワークを利用できません。必ず中間に状態を持つ必要があります。

;So, here's the Titanic pattern, in which we write messages to disk to ensure they never get lost, no matter how sporadically clients and workers are connected. As we did for service discovery, we're going to layer Titanic on top of MDP rather than extend it. It's wonderfully lazy because it means we can implement our fire-and-forget reliability in a specialized worker, rather than in the broker. This is excellent for several reasons:

そこでタイタニックパターンです。
メッセージをディスクに保存することで、散発的にクライアントやワーカーが接続して来た場合でもメッセージを失わない事を保証します。
サービスディスカバリーと同様に、このタイタニックパターンをMDPプロトコルの上に追加実装します。
これはブローカーに実装するのではなくワーカー側で信頼せい

;* It is much easier because we divide and conquer: the broker handles message routing and the worker handles reliability.
;* It lets us mix brokers written in one language with workers written in another.
;* It lets us evolve the fire-and-forget technology independently.

;The only downside is that there's an extra network hop between broker and hard disk. The benefits are easily worth it.

* 単純な分割統治をおこなうので簡単です。
* ブローカーを実装する言語とは別の言語でワーカーを実装することが出来ます。
* fire-and-forgetテクノロジーを独自に進化させます。

唯一の欠点は、ブローカーとハードディスクの間で幾つかのオーバーヘッドを必要とする事ですが、利点は欠点に勝るでしょう。

;There are many ways to make a persistent request-reply architecture. We'll aim for one that is simple and painless. The simplest design I could come up with, after playing with this for a few hours, is a "proxy service". That is, Titanic doesn't affect workers at all. If a client wants a reply immediately, it talks directly to a service and hopes the service is available. If a client is happy to wait a while, it talks to Titanic instead and asks, "hey, buddy, would you take care of this for me while I go buy my groceries?"

永続的なリクエスト・応答アーキテクチャを実現する方法はいくつもありますが、今回私達はその中で最も単純で痛みの無い方法を利用します。

タイタニックパターンは全てのワーカーに影響を与えるわけではありません。

![タイタニックパターン](images/fig51.eps)

;Titanic is thus both a worker and a client. The dialog between client and Titanic goes along these lines:

この様に、タイタニックはワーカーとクライアントとの間に位置していて、クライアントとタイタニックのやりとりは以下通りです。

;* Client: Please accept this request for me. Titanic: OK, done.
;* Client: Do you have a reply for me? Titanic: Yes, here it is. Or, no, not yet.
;* Client: OK, you can wipe that request now, I'm happy. Titanic: OK, done.

* クライアント「このリクエストを受け付けてくれる?」タイタニック「OK、完了」
* クライアント「それじゃあ応答を送ってくれる?」タイタニック「はい、これが応答ね」もしくは「そんなの無いよ」
* クライアント「さっき送信したリクエストを削除してもらえる?」タイタニック「OK、完了」

;Whereas the dialog between Titanic and broker and worker goes like this:

一方、タイタニックとブローカー間でのやりとりは以下の通りです。

;* Titanic: Hey, Broker, is there an coffee service? Broker: Uhm, Yeah, seems like.
;* Titanic: Hey, coffee service, please handle this for me.
;* Coffee: Sure, here you are.
;* Titanic: Sweeeeet!

* タイタニック「おーい、ブローカーさん。コーヒーサービスは動いてる?」ブローカー「うむ、動いているようだ」
* タイタニック「おーい、コーヒーサービスさん・このリクエストを処理してもらえる?」
* コーヒーサービス「はい、どうぞ」
* タイタニック「ありがとーーーーーー！」

;You can work through this and the possible failure scenarios. If a worker crashes while processing a request, Titanic retries indefinitely. If a reply gets lost somewhere, Titanic will retry. If the request gets processed but the client doesn't get the reply, it will ask again. If Titanic crashes while processing a request or a reply, the client will try again. As long as requests are fully committed to safe storage, work can't get lost.

それでは起こり得る障害のシナリオを見て行きましょう。
リクエストを処理中のワーカーがクラッシュした場合、タイタニックは何度でも再試行します。
応答が失われてしまった場合も再試行を行います。
リクエストが処理されたにもかかわらず、クライアントが応答を受け取れなかった場合は再度問い合わせが行われます。
リクエストの処理中にタイタニックがクラッシュした場合、クライアントは再試行を行います。
リクエストが確実にディスクに書き込まれていれば、メッセージを失うことはありません。

;The handshaking is pedantic, but can be pipelined, i.e., clients can use the asynchronous Majordomo pattern to do a lot of work and then get the responses later.

やりとりはやや複雑ですが、パイプライン化が可能です。
例えばクライアントが非同期なMajordomoパターンをしている場合、レスポンスを受け取るまでの間に多くの処理を行うことが可能です。

;We need some way for a client to request its replies. We'll have many clients asking for the same services, and clients disappear and reappear with different identities. Here is a simple, reasonably secure solution:

クライアントのリクエストに対して応答を返すには工夫が必要です。

異なるIDを持った多くのクライアントが同一のサービスに対してリクエストを行っているとします。
安全で手頃な解決方法は以下の通りです。

;* Every request generates a universally unique ID (UUID), which Titanic returns to the client after it has queued the request.
;* When a client asks for a reply, it must specify the UUID for the original request.

* リクエストをキューに格納した後にタイタニックはクライアントに対してUUIDを生成して返却します。
* クライアントはこのUUIDを指定して応答を取得する必要があります。

;In a realistic case, the client would want to store its request UUIDs safely, e.g., in a local database.

実際のケースではクライアントはこのUUIDをローカルのデータベースなどにに保存することになるでしょう。

;Before we jump off and write yet another formal specification (fun, fun!), let's consider how the client talks to Titanic. One way is to use a single service and send it three different request types. Another way, which seems simpler, is to use three services:

正式な仕様を作成する楽しい作業に移る前に、まずクライアントとタイタニックがどの様な会話を行うか考えてみましょう。
これには2種類の実装方法があります。
ひとつ目は1つサービスで複数のリクエスト種別を扱う方法です。
もう一方は、以下のような3つのサービスを用意する方法です。

;* titanic.request: store a request message, and return a UUID for the request.
;* titanic.reply: fetch a reply, if available, for a given request UUID.
;* titanic.close: confirm that a reply has been stored and processed.

* titanic.request: リクエストメッセージを保存し、UUIDを返却するサービス。
* titanic.reply: UUIDに対応する応答を返却するサービス。
* titanic.close: 応答が格納されたかどうかを確認するサービス。

;We'll just make a multithreaded worker, which as we've seen from our multithreading experience with ØMQ, is trivial. However, let's first sketch what Titanic would look like in terms of ØMQ messages and frames. This gives us the Titanic Service Protocol (TSP).

ここでは、単純にマルチスレッドワーカーを作成して3つのサービスを提供します。
まずはタイタニックがやりとりするメッセージフレームを設計してみましょう。
これをタイタニック・サービス・プロトコル(以下TSP)と呼びます。

;Using TSP is clearly more work for client applications than accessing a service directly via MDP. Here's the shortest robust "echo" client example:

MDPの場合と比較して、TSPは明らかにクライアントの作業量が多くなります。
以下に短くて堅牢な「echoクライアント」のサンプルコードを示します。

~~~ {caption="ticlient: タイタニッククライアント"}
include(examples/EXAMPLE_LANG/ticlient.EXAMPLE_EXT)
~~~

;Of course this can be, and should be, wrapped up in some kind of framework or API. It's not healthy to ask average application developers to learn the full details of messaging: it hurts their brains, costs time, and offers too many ways to make buggy complexity. Additionally, it makes it hard to add intelligence.

もちろん、この様なコードはフレームワークやAPIの中に隠蔽化されるでしょう。
ただ、隠蔽化してしまうとメッセージングを学ぼうとしているアプリケーション開発者の障害になります。
頭を悩ませ、時間を掛けて多くのバグを解決してこそ、知性が磨かれるのです。

;For example, this client blocks on each request whereas in a real application, we'd want to be doing useful work while tasks are executed. This requires some nontrivial plumbing to build a background thread and talk to that cleanly. It's the kind of thing you want to wrap in a nice simple API that the average developer cannot misuse. It's the same approach that we used for Majordomo.

クライアントがリクエストを行っている間はブロックするアプリケーションが多いですが、タスクを実行している間に別のタスクを行いたい事もあるでしょう。
このような要件を実現するには工夫が必要です。
Majordomoの時に行ったように、うまくAPIで隠蔽化してやれば一般的なアプリケーション開発者が誤用する事は少なくなります。

;Here's the Titanic implementation. This server handles the three services using three threads, as proposed. It does full persistence to disk using the most brutal approach possible: one file per message. It's so simple, it's scary. The only complex part is that it keeps a separate queue of all requests, to avoid reading the directory over and over:

今度はタイタニックブローカーの実装です。
先ほど提案した通り、このブローカーは3つのスレッドで3つのサービスを提供します。
そしてメッセージ1つにつき1ファイルという最も単純かつ最も荒っぽい構成でディスクへの永続化を行います。
唯一複雑な部分は、ディレクトリを何度も走査をするのを避けるために、全てのリクエストを別のキューで保持している所です。

~~~ {caption="titanic: タイタニックブローカー"}
include(examples/EXAMPLE_LANG/ticlient.EXAMPLE_EXT)
~~~

;To test this, start mdbroker and titanic, and then run ticlient. Now start mdworker arbitrarily, and you should see the client getting a response and exiting happily.

これをテストするには、mdbrokerとtitanicを開始してticlientを実行します。
そして、mdworkerが動作した段階でクライアントは応答を受け取るのを確認できるでしょう。

;Some notes about this code:

このコードの注意点は、

;* Note that some loops start by sending, others by receiving messages. This is because Titanic acts both as a client and a worker in different roles.
;* The Titanic broker uses the MMI service discovery protocol to send requests only to services that appear to be running. Since the MMI implementation in our little Majordomo broker is quite poor, this won't work all the time.
;* We use an inproc connection to send new request data from the titanic.request service through to the main dispatcher. This saves the dispatcher from having to scan the disk directory, load all request files, and sort them by date/time.

* ループの開始時にメッセージを送信したり受信したりしていますが、これはタイタニックが役割の異なる、クライアントとワーカーの双方と通信するためです。
* このタイタニックブローカーは、動作しているサービスだけにメッセージを送信する為に、MMIサービスディスカバリープロトコルを利用します。しかしこのサンプルコードで実装したMajordomoブローカーは少しお馬鹿さんなので、上手く動かない場合もあります。
* 新規リクエストをtitanic.requestサービスからメインディスパッチャーへ送信する手段にプロセス内通信を利用しています。これによりディスパッチャーが毎回ディレクトリを走査したり、時刻でソートしたりする処理を省くことが出来ます。

;The important thing about this example is not performance (which, although I haven't tested it, is surely terrible), but how well it implements the reliability contract. To try it, start the mdbroker and titanic programs. Then start the ticlient, and then start the mdworker echo service. You can run all four of these using the -v option to do verbose activity tracing. You can stop and restart any piece except the client and nothing will get lost.

タイタニックで重要な事は、パフォーマンスは低いけれども、信頼性の保証された実装である事です。
mdbrokerとtitanicを起動し、続いて、ticlientとechoサービスのmdworkerを起動してみて下さい。
これら全てのプログラムは-vオプションを指定して詳細な動きトレースすることが出来ます。
メッセージを失うこと無く、全ての部品を再起動することを確認できるはずです。

;If you want to use Titanic in real cases, you'll rapidly be asking "how do we make this faster?"

実際のケースでこのタイタニックパターンを利用する場合、「どうすれば早くなるか?」を考える必要があるでしょう。

;Here's what I'd do, starting with the example implementation:

以下は私が行った高速化の為の工夫です。

;* Use a single disk file for all data, rather than multiple files. Operating systems are usually better at handling a few large files than many smaller ones.
;* Organize that disk file as a circular buffer so that new requests can be written contiguously (with very occasional wraparound). One thread, writing full speed to a disk file, can work rapidly.
;* Keep the index in memory and rebuild the index at startup time, from the disk buffer. This saves the extra disk head flutter needed to keep the index fully safe on disk. You would want an fsync after every message, or every N milliseconds if you were prepared to lose the last M messages in case of a system failure.
;* Use a solid-state drive rather than spinning iron oxide platters.
;* Pre-allocate the entire file, or allocate it in large chunks, which allows the circular buffer to grow and shrink as needed. This avoids fragmentation and ensures that most reads and writes are contiguous.

* 複数のファイルではなく、単一のファイルを利用します。一般的にOSは複数の小さなファイル扱うより、大きなファイルひとつを処理したほうが効率が良いです。
* 新規リクエストを連続した領域に書き込めるように調整してやります。
* 起動時にメモリ上にインデックスを構築する事で余計なディスクアクセスを回避できます。障害時にメッセージを失わないようにするには、受信の後にfsyncすると良いでしょう。
* 錆びた鉄のプラッターの代わりにSSDを利用する。
* 必要に応じて増減可能な巨大なファイルをあらかじめ作成しておきます。これによりデータの連続性を保証し、フラグメンテーションを回避できます。

;And so on. What I'd not recommend is storing messages in a database, not even a "fast" key/value store, unless you really like a specific database and don't have performance worries. You will pay a steep price for the abstraction, ten to a thousand times over a raw disk file.

それと、高速なキー・バリュー・ストアではないデーターベースにメッセージを格納することはあまり推奨できません。
特定のデーターベースが大好きだというなら話は別ですが、ディスクファイルを抽象化するために法外なコストを支払うことになります。

;If you want to make Titanic even more reliable, duplicate the requests to a second server, which you'd place in a second location just far away enough to survive a nuclear attack on your primary location, yet not so far that you get too much latency.

タイタニックの信頼性を更に高めたいのであれば、核攻撃の届かいない2台目のサーバーに重複したリクエストを送信すると良いでしょう。
レイテンシが大きいでしょうけどね。

;If you want to make Titanic much faster and less reliable, store requests and replies purely in memory. This will give you the functionality of a disconnected network, but requests won't survive a crash of the Titanic server itself.

タイタニックの信頼性を下げて、リクエストと応答をメモリに格納する事で非接続性のネットワーク機能を実現できますが、タイタニックサーバー自体の障害でメッセージは失われてしまいます。

## 高可用性ペア (バイナリー・スターパターン)

![高可用性ペアの通常状態](images/fig52.eps)

;The Binary Star pattern puts two servers in a primary-backup high-availability pair. At any given time, one of these (the active) accepts connections from client applications. The other (the passive) does nothing, but the two servers monitor each other. If the active disappears from the network, after a certain time the passive takes over as active.

バイナリー・スターパターンはプライマリー・バックアップに対応する2つのサーバーを用いて信頼性を高めます。
ある時点では、ひとつのサーバー(アクティブ)がクライアントからの接続を受け付け、もう片方(非アクティブ)はなにもしません。
しかし、この2つのサーバーはお互いに監視しています。
ネットワーク上からアクティブサーバーが居なくなると、すぐに非アクティブサーバーがアクティブサーバーの役割を引き継ぎます。

;We developed the Binary Star pattern at iMatix for our OpenAMQ server. We designed it:

私達はOpenAMQサーバーの頃にバイナリー・スターパターンを開発しました。
以下の様に設計されています。

;* To provide a straightforward high-availability solution.
;* To be simple enough to actually understand and use.
;* To fail over reliably when needed, and only when needed.

* 単純な高可用性ソリューションを提供する。
* 簡単に理解できて使いやすいこと。
* 必要な場合のみフェイルオーバーします。

;Assuming we have a Binary Star pair running, here are the different scenarios that will result in a failover:

バイナリー・スターパターンでは、以下のパターンでフェイルオーバーが発生します。

;* The hardware running the primary server has a fatal problem (power supply explodes, machine catches fire, or someone simply unplugs it by mistake), and disappears. Applications see this, and reconnect to the backup server.
;* The network segment on which the primary server sits crashes—perhaps a router gets hit by a power spike—and applications start to reconnect to the backup server.
;* The primary server crashes or is killed by the operator and does not restart automatically.

* プライマリーサーバーに致命的な問題(爆発、火災、電源を引っこ抜いた、など)が発生した場合。アプリケーションはそれを確認し、バックアップサーバーに再接続を行います。
* プライマリーサーバーの居るネットワークセグメントで障害が発生した場合。恐らくルーターが高負荷になるでしょうが、アプリケーションはバックアップサーバーに再接続を行うでしょう。
* プライマリーサーバーがクラッシュした場合、もしくは再起動を行って自動的に起動しなかった場合。

![High-availability Pair During Failover](images/fig53.eps)

;Recovery from failover works as follows:

フェイルオーバーから復旧するには以下の事を行います。

;* The operators restart the primary server and fix whatever problems were causing it to disappear from the network.
;* The operators stop the backup server at a moment when it will cause minimal disruption to applications.
;* When applications have reconnected to the primary server, the operators restart the backup server.

* プライマリーサーバーを起動し、ネットワークから見えるようにしてやります。
* 一時的にバックアップサーバーを停止します。これによりアプリケーションからの接続が切断されます。
* アプリケーションがプライマリーサーバーに再接続するのを確認し、バックアップサーバーを起動します。

;Recovery (to using the primary server as active) is a manual operation. Painful experience teaches us that automatic recovery is undesirable. There are several reasons:

フェイルオーバーからの復旧は手動で行います。
復旧を自動的に行うことが良くない事を私達は経験済みです。
これには以下の理由があります。

;* Failover creates an interruption of service to applications, possibly lasting 10-30 seconds. If there is a real emergency, this is much better than total outage. But if recovery creates a further 10-30 second outage, it is better that this happens off-peak, when users have gone off the network.
;* When there is an emergency, the absolute first priority is certainty for those trying to fix things. Automatic recovery creates uncertainty for system administrators, who can no longer be sure which server is in charge without double-checking.
;* Automatic recovery can create situations where networks fail over and then recover, placing operators in the difficult position of analyzing what happened. There was an interruption of service, but the cause isn't clear.

* フェイルオーバーは恐らく10〜30秒のサービス停止を発生させます。そして復旧にも同等の時間が掛かります。これはユーザーの少ない時間帯に行ったほうが良いでしょう。
* 緊急事態に陥った場合、最も重要なのは確実に修復させる事です。自動復旧を行ったとしても、システム管理者のダブルチェック無しでは復旧した事を確証出来ません。
* 例えば一時的なネットワーク障害でフェイルオーバーした場合に自動復旧を行った場合、サービス停止の原因を特定することが難しくなります。

;Having said this, the Binary Star pattern will fail back to the primary server if this is running (again) and the backup server fails. In fact, this is how we provoke recovery.

とは言っても、バイナリー・スターパターンではプライマリーサーバーに障害が発生し、その後バックアップサーバーで障害が発生すると、事実上自動復旧した様になります。

;The shutdown process for a Binary Star pair is to either:

バイナリー・スターパターンをシャットダウンさせるには以下の方法があります。

;* Stop the passive server and then stop the active server at any later time, or
;* Stop both servers in any order but within a few seconds of each other.

* まず非アクティブサーバーを停止し、その後アクティブサーバーを停止する。
* 2つのサーバーをほぼ同時に停止する。

;Stopping the active and then the passive server with any delay longer than the failover timeout will cause applications to disconnect, then reconnect, and then disconnect again, which may disturb users.

アクティブサーバーをを停止し、時間を空けて非アクティブサーバーを停止した場合、アプリケーションは切断、再接続、切断という動作となりユーザーを混乱させてしまいます。

### 詳細な要件
;Binary Star is as simple as it can be, while still working accurately. In fact, the current design is the third complete redesign. Each of the previous designs we found to be too complex, trying to do too much, and we stripped out functionality until we came to a design that was understandable, easy to use, and reliable enough to be worth using.

バイナリー・スターパターンは出来るだけ単純に動作します。
実は私達はこの設計を3度再設計したという経緯があります。
以前の設計はとても複雑だと気がついたので簡単に理解して利用できるように機能を削ってきました。

;These are our requirements for a high-availability architecture:

高可用性アーキテクチャでは以下の要件を満たす必要があるでしょう。

;* The failover is meant to provide insurance against catastrophic system failures, such as hardware breakdown, fire, accident, and so on. There are simpler ways to recover from ordinary server crashes and we already covered these.
;* Failover time should be under 60 seconds and preferably under 10 seconds.
;* Failover has to happen automatically, whereas recovery must happen manually. We want applications to switch over to the backup server automatically, but we do not want them to switch back to the primary server except when the operators have fixed whatever problem there was and decided that it is a good time to interrupt applications again.
;* The semantics for client applications should be simple and easy for developers to understand. Ideally, they should be hidden in the client API.
;* There should be clear instructions for network architects on how to avoid designs that could lead to split brain syndrome, in which both servers in a Binary Star pair think they are the active server.
;* There should be no dependencies on the order in which the two servers are started.
;* It must be possible to make planned stops and restarts of either server without stopping client applications (though they may be forced to reconnect).
;* Operators must be able to monitor both servers at all times.
;* It must be possible to connect the two servers using a high-speed dedicated network connection. That is, failover synchronization must be able to use a specific IP route.

* フェイルオーバーはハードウェア障害、火災などの重大なシステム障害に対する保険です。一般的な障害から復旧するための方法は既に学んだ様に単純な方法があります。
* フェイルオーバーに要する時間は60秒以下にすべきであり、できれば10秒以下が望ましいでしょう。
* フェイルオーバーは自動で行いますが、フェイルオーバーからの復旧は手動で行う必要があります。バックアップサーバーへの切り替えは自動的に行われて問題ありませんが、プライマリーサーバーへの切り替えは問題が修正されているかどうかをオペレーターが確認し、適切なタイミングを見極める必要があるからです。
* プロトコルは開発者が理解しやすいように単純かつ簡単にすべきであり、理想的にはクライアントAPIで隠蔽するのが良いでしょう。
* ネットワークが分断された際に発生するスプリットブレイン問題を回避するための明確なネットワーク設計手順が必要です。
* サーバーを起動する順序に依存せず動作しなければなりません。
* クライアントが停止すること無く（再接続は発生するでしょうが）、どちらのサーバーも停止したり再起動を行ったりできるようにしなければなりません。
* オペレーターは常に2つのサーバーを監視する必要があります。
* 2つのサーバーは高速なネットワーク回線で接続され、フェイルオーバーは特定のIP経路で同期する必要があります。

;We make the following assumptions:

以下の事を仮定します。

;* A single backup server provides enough insurance; we don't need multiple levels of backup.
;* The primary and backup servers are equally capable of carrying the application load. We do not attempt to balance load across the servers.
;* There is sufficient budget to cover a fully redundant backup server that does nothing almost all the time.

* ひとつのバックアップサーバーで十分な保険であるとし、複数のバックアップサーバーを必要としません。
* プライマリーサーバーとバックアップサーバーは各1台でアプリケーションの負荷に耐えられるとします。これらのサーバーで負荷分散しないでください。
* 常時何も行わないバックアップサーバーを動作させるための予算を確保して下さい。

;We don't attempt to cover the following:

以下の事についてはここでは触れません。

;* The use of an active backup server or load balancing. In a Binary Star pair, the backup server is inactive and does no useful work until the primary server goes offline.
;* The handling of persistent messages or transactions in any way. We assume the existence of a network of unreliable (and probably untrusted) servers or Binary Star pairs.
;* Any automatic exploration of the network. The Binary Star pair is manually and explicitly defined in the network and is known to applications (at least in their configuration data).
;* Replication of state or messages between servers. All server-side state must be recreated by applications when they fail over.

* アクティブバックアップサーバー、あるいは負荷分散を行うこと。バイナリー・スターパターンではバックアップサーバーは非アクティブであり、プライマリーサーバーが非アクティブにならない限り利用できません。
* 信頼性の低いネットワークを利用していることを前提とした場合、何らかの方法でメッセージの永続化、もしくはトランザクションを行う必要があります。
* サーバーの自動検出。バイナリー・スターパターンではネットワークの設定を主導で行い、アプリケーションはこの設定を知っているとします。
* メッセージや状態のサーバー間でのレプリケーション。フェイルオーバーが発生するとセッションを1からやり直すこととします。

;Here is the key terminology that we use in Binary Star:

バイナリー・スターパターンで利用する用語は以下の通りです。

;* Primary: the server that is normally or initially active.
;* Backup: the server that is normally passive. It will become active if and when the primary server disappears from the network, and when client applications ask the backup server to connect.
;* Active: the server that accepts client connections. There is at most one active server.
;* Passive: the server that takes over if the active disappears. Note that when a Binary Star pair is running normally, the primary server is active, and the backup is passive. When a failover has happened, the roles are switched.

* プライマリー: 初期または通常状態でアクティブなサーバー。
* バックアップ: 通常状態で非アクティブなサーバー。プライマリーサーバーがネットワーク上から居なくなった際にアクティブになり、クライアントはこちらに接続します。
* アクティブ: クライアントからの接続を受け付けているサーバー。唯一ひとつのサーバーだけがアクティブになれます。
* 非アクティブ: アクティブが居なくなった際に役割を引き継ぐサーバー。バイナリー・スターパターンでは通常プライマリーサーバーがアクティブであり、バックアップサーバーが非アクティブです。フェイルオーバーが起こった際はこれが逆転します。

;To configure a Binary Star pair, you need to:

バイナリー・スターパターンでは以下の情報が設定されている必要があります。

;1. Tell the primary server where the backup server is located.
;2. Tell the backup server where the primary server is located.
;3. Optionally, tune the failover response times, which must be the same for both servers.

1. プライマリーサーバーはバックアップサーバーのアドレスを知っていること
2. バックアップサーバーはプライマリーサーバーのアドレスを知っていること
3. フェイルオーバーの応答時間は2つのサーバーで同じである必要があります。

;The main tuning concern is how frequently you want the servers to check their peering status, and how quickly you want to activate failover. In our example, the failover timeout value defaults to 2,000 msec. If you reduce this, the backup server will take over as active more rapidly but may take over in cases where the primary server could recover. For example, you may have wrapped the primary server in a shell script that restarts it if it crashes. In that case, the timeout should be higher than the time needed to restart the primary server.

チューニングパラメーターとしては、フェイルオーバーを行うためにサーバー同士がお互いの状態を確認する間隔を設定します。今回の例ではフェイルオーバーのタイムアウトは既定で2秒とします。
この数値を小さくすることでより迅速にバックアップサーバーがアクティブサーバーの役割を引き継ぐことが出来ます。
しかし、予期しないフェイルオーバーが発生する可能性があります。
例えば、プライマリーサーバーがクラッシュした場合に自動的に再起動を行うスクリプトを書いた場合、タイムアウトはプライマリーサーバーの再起動に要する時間より長く設定すべきでしょう。

;For client applications to work properly with a Binary Star pair, they must:

バイナリー・スターパターンで正しくクライアントアプリケーションが正しく動作するには、クライアントを以下の様に実装する必要があります。

;1. Know both server addresses.
;2. Try to connect to the primary server, and if that fails, to the backup server.
;3. Detect a failed connection, typically using heartbeating.
;4. Try to reconnect to the primary, and then backup (in that order), with a delay between retries that is at least as high as the server failover timeout.
;5. Recreate all of the state they require on a server.
;6. Retransmit messages lost during a failover, if messages need to be reliable.

1. 2つのサーバーのアドレスを知っている必要があります。
2. まず、プライマリーサーバーに接続し、失敗したらバックアップサーバーに接続します。
3. コネクションの切断を検出するために、ハートビートを行います。
4. 再接続を行う際、まずプライマリーサーバーに接続し、次にバックアップサーバーに接続します。リトライ間隔はフェイルオーバータイムアウトと同等の間隔で行います。
5. 再接続を行う歳、セッションを再生成します。
6. 信頼性を高めたい場合はフェイルオーバーが行われた際に失われたメッセージを再送信します。

;It's not trivial work, and we'd usually wrap this in an API that hides it from real end-user applications.

これらを実装するのはそれほど簡単な仕事ではありませんので、通常はAPIの中に隠蔽すると良いでしょう。

;These are the main limitations of the Binary Star pattern:

バイナリー・スターパターンの主な制限は以下の通りです。

;* A server process cannot be part of more than one Binary Star pair.
;* A primary server can have a single backup server, and no more.
;* The passive server does no useful work, and is thus wasted.
;* The backup server must be capable of handling full application loads.
;* Failover configuration cannot be modified at runtime.
;* Client applications must do some work to benefit from failover.

* 1プロセスではバイナリー・スターパターンを構成できません。
* プライマリー・サーバーは1つのバックアップサーバーを持ち、これ以上は増やせません。
* 非アクティブサーバーは通常動作しません。
* プライマリーサーバーとバックアプサーバーは各々がアプリケーションの負荷に耐えられなければなりません。
* フェイルオーバーの設定は実行中に変更出来ません。
* クライアントアプリケーションはフェイルオーバーに対応する為のの機能を持っている必要があります。

### スプリット・ブレイン問題の防止
;Split-brain syndrome occurs when different parts of a cluster think they are active at the same time. It causes applications to stop seeing each other. Binary Star has an algorithm for detecting and eliminating split brain, which is based on a three-way decision mechanism (a server will not decide to become active until it gets application connection requests and it cannot see its peer server).

クラスターが分断し、個々の部品が同じタイミングでアクティブになろうとするとスプリット・ブレイン問題が発生します。
これはアプリケーションの停止を引き起こします。
バイナリー・スターパターンはスプリット・ブレイン問題を検出し解決するアルゴリズムを持っています。
サーバー同士がお互いに通信して判断するのではなく、クライアントからの接続を受けてから自分がアクティブであると判断します。

;However, it is still possible to (mis)design a network to fool this algorithm. A typical scenario would be a Binary Star pair, that is distributed between two buildings, where each building also had a set of applications and where there was a single network link between both buildings. Breaking this link would create two sets of client applications, each with half of the Binary Star pair, and each failover server would become active.

しかし、このアルゴリズムを騙す為の意図的なネットワークを構築することは可能です。
この典型的なシナリオは、バイナリー・スターの対が2つの建物に分散されており、各々の建物にクライアントアプリケーションが存在するネットワークです。
この時、建物間のネットワークが切断されるとバイナリー・スターの対は両方共アクティブになるでしょう。

;To prevent split-brain situations, we must connect a Binary Star pair using a dedicated network link, which can be as simple as plugging them both into the same switch or, better, using a crossover cable directly between two machines.

このスプリット・ブレイン問題を防ぐには、単純にバイナリー・スターの対を同じネットワークスイッチに接続するか、クロスケーブルでお互いに直接接続すると良いでしょう。

;We must not split a Binary Star architecture into two islands, each with a set of applications. While this may be a common type of network architecture, you should use federation, not high-availability failover, in such cases.

バイナリー・スターパターンではアプリケーションの存在するネットワークを2つの島に分けてはいけません。
この様なネットワーク構成である場合は、フェイルオーバーではなくフェデレーションパターンを利用すべきでしょう。

;A suitably paranoid network configuration would use two private cluster interconnects, rather than a single one. Further, the network cards used for the cluster would be different from those used for message traffic, and possibly even on different paths on the server hardware. The goal is to separate possible failures in the network from possible failures in the cluster. Network ports can have a relatively high failure rate.

神経質なネットワークでは、単一では無く2つのクラスターを相互接続することがあります。
さらに、場合によっては相互接続の為の通信とメッセージ処理の通信で異なるネットワークカードが利用される場合があるでしょう。
まずはネットワーク障害とクラスター内の障害とを切り分ける事が重要です。
ネットワークポートはかなりの頻度で壊れることがあるからです。

### バイナリー・スターの実装
;Without further ado, here is a proof-of-concept implementation of the Binary Star server. The primary and backup servers run the same code, you choose their roles when you run the code:

前置きはこれくらいにしおいて、実際に動作するバイナリー・スターサーバーの実装を見て行きましょう。
プライマリーとバックアップの役割は実行時に指定しますので、コード自体は同じものです。

~~~ {caption="bstarsrv: バイナリー・スター サーバー"}
include(examples/EXAMPLE_LANG/bstarsrv.EXAMPLE_EXT)
~~~

;And here is the client:

そしてこちらがクライアントのコードです。

~~~ {caption="bstarcli: バイナリー・スター クライアント"}
include(examples/EXAMPLE_LANG/bstarcli.EXAMPLE_EXT)
~~~

;To test Binary Star, start the servers and client in any order:

バイナリー・スターのテストを行うには、以下のように2つサーバーとクライアントを起動します。起動する順序はどちらが先でも構いません。

~~~
bstarsrv -p     # Start primary
bstarsrv -b     # Start backup
bstarcli
~~~

;You can then provoke failover by killing the primary server, and recovery by restarting the primary and killing the backup. Note how it's the client vote that triggers failover, and recovery.

この状態でプライマリーサーバーを停止することにより、フェイルオーバーを発生させることができます。
そしてプライマリーを起動し、バックアップを停止する事で復旧が完了します。
フェイルオーバーや復旧のタイミングはクライアントが判断する事に注意して下さい。

;Binary star is driven by a finite state machine. Events are the peer state, so "Peer Active" means the other server has told us it's active. "Client Request" means we've received a client request. "Client Vote" means we've received a client request AND our peer is inactive for two heartbeats.

バイナリー・スターは有限状態オートマトンにより動作します。
「Peer Active」は相手側のサーバーがアクティブ状態であるという意味のイベントです。
「Client Request」はクライアントからのリクエストを受け取ったことを意味するイベントです。
「Client Vote」はパッシブ状態のサーバーがクライアントからのリクエストを受け取り、アクティブ状態に遷移します。

;Note that the servers use PUB-SUB sockets for state exchange. No other socket combination will work here. PUSH and DEALER block if there is no peer ready to receive a message. PAIR does not reconnect if the peer disappears and comes back. ROUTER needs the address of the peer before it can send it a message.

サーバー同士で状態を通知するためにPUB-SUBソケットを利用しています。
他のソケットの組み合わせでは上手く動作しないでしょう。
PUSHとDEALERソケットの組み合わせでは通信相手がメッセージを受信する準備が出来ていない場合にブロックしてしまいます。
PAIRソケットでは通信相手と一時的に通信できなくなった場合に再接続を行いません。
ROUTERソケットではメッセージを送信する際に通信相手のアドレスが必要です。

![バイナリー・スター有限状態オートマトン](images/fig54.eps)

### バイナリー・スター・リアクター

;Binary Star is useful and generic enough to package up as a reusable reactor class. The reactor then runs and calls our code whenever it has a message to process. This is much nicer than copying/pasting the Binary Star code into each server where we want that capability.

バイナリー・スターを再利用可能なリアクタークラスとしてパッケージングすると汎用的で便利です。
リアクターにはメッセージを処理する関数を渡して実行します。
既存のサーバーに対してバイナリー・スターの機能をコピペするよりはこちらの方が良いでしょう。

;In C, we wrap the CZMQ zloop class that we saw before. zloop lets you register handlers to react on socket and timer events. In the Binary Star reactor, we provide handlers for voters and for state changes (active to passive, and vice versa). Here is the bstar API:

C言語の場合、既に紹介したCZMQのzloopクラスを利用します。
zloopにはソケットやタイマーイベントに反応するハンドラーを登録する事ができます。
バイナリー・スターの場合、アクティブから非アクティブへの遷移などの状態の変更に関するハンドラを登録します。
こちらがbstarクラスの実装です。

~~~ {caption="bstar: バイナリー・スター リアクター"}
include(examples/EXAMPLE_LANG/bstar.EXAMPLE_EXT)
~~~

;This gives us the following short main program for the server:

これを利用することでサーバーのメインプログラムはこんなにも短くなります。

~~~ {caption="bstarsrv2: リアクタークラスを利用したバイナリー・スター サーバー"}
include(examples/EXAMPLE_LANG/bstarsrv2.EXAMPLE_EXT)
~~~

## ブローカー不在の信頼性(フリーランスパターン)
;It might seem ironic to focus so much on broker-based reliability, when we often explain ØMQ as "brokerless messaging". However, in messaging, as in real life, the middleman is both a burden and a benefit. In practice, most messaging architectures benefit from a mix of distributed and brokered messaging. You get the best results when you can decide freely what trade-offs you want to make. This is why I can drive twenty minutes to a wholesaler to buy five cases of wine for a party, but I can also walk ten minutes to a corner store to buy one bottle for a dinner. Our highly context-sensitive relative valuations of time, energy, and cost are essential to the real world economy. And they are essential to an optimal message-based architecture.

これまでØMQは「ブローカー不在のメッセージング」であると説明してきましたので、ブローカー中心の信頼性に頼ることは皮肉に見えるかもしれません。
しかし、大抵の場合実際のメッセージング・アーキテクチャは分散とブローカーによるメッセージングを組み合わせて利用されます。
あなたはトレードオフを理解した上で最良の方法を選択することができます。
例えば、パーティ用のワインを5ケース買うために遠くの卸業者まで車を20分走らせることも出来ますし、夕飯のために1本のワインを買うだけであれば歩いて近くのスーパーに買いに行くという選択も出来ます。
時間、エネルギー、価格に対する評価は現実の世界の経済では大きく状況に依存して決まります。
そしてこれらはメッセージングアーキテクチャの最適化の為には不可欠な事です。

;This is why ØMQ does not impose a broker-centric architecture, though it does give you the tools to build brokers, aka proxies, and we've built a dozen or so different ones so far, just for practice.

これが、ØMQはブローカー中心のアーキテクチャを強制しないのにも関わらず、ブローカーやプロキシなどの例を多く説明してきた理由です。

;So we'll end this chapter by deconstructing the broker-based reliability we've built so far, and turning it back into a distributed peer-to-peer architecture I call the Freelance pattern. Our use case will be a name resolution service. This is a common problem with ØMQ architectures: how do we know the endpoint to connect to? Hard-coding TCP/IP addresses in code is insanely fragile. Using configuration files creates an administration nightmare. Imagine if you had to hand-configure your web browser, on every PC or mobile phone you used, to realize that "google.com" was "74.125.230.82".

それでは、これまで説明してきたブローカー中心の信頼性を解体し、フリーランスパターンと呼んでいるP2Pな分散アーキテクチャを紹介してこの章を終わります。
このパターンは名前解決システムの様な用途で利用します。
ØMQアーキテクチャにおいて、接続先のエンドポイントを知る方法は一般的な課題です。
IPアドレスをハードコードなんてしたくは無いでしょうし、設定ファイルを作成すると管理者が悪夢を見るでしょう。
あなたの利用している全てのPCや携帯電話のブラウザで「google.com」や「74.125.230.82」という文字を入力することを想像してみて下さい。

;A ØMQ name service (and we'll make a simple implementation) must do the following:

ここで実装する単純なØMQネームサービスは以下の事を行う必要があります。

;* Resolve a logical name into at least a bind endpoint, and a connect endpoint. A realistic name service would provide multiple bind endpoints, and possibly multiple connect endpoints as well.
;* Allow us to manage multiple parallel environments, e.g., "test" versus "production", without modifying code.
;* Be reliable, because if it is unavailable, applications won't be able to connect to the network.

* 少なくとも、論理名からbindするエンドポイントへ名前解決を行い、エンドポイントに接続します。ひとつのサービス名は複数のエンドポイントを持つかもしれません。
* 例えば、テスト環境と本番環境のように複数の環境をコードを書き換えずに切り替えられる事が出来ます。
* これがサービス不能になるとアプリケーションがネットワークに接続できなくなるので信頼性は高くなければなりません。

;Putting a name service behind a service-oriented Majordomo broker is clever from some points of view. However, it's simpler and much less surprising to just expose the name service as a server to which clients can connect directly. If we do this right, the name service becomes the only global network endpoint we need to hard-code in our code or configuration files.

サービス指向のMajordomoブローカーの背後にネームサービスを配置することはそこそこ賢い考えです。
しかし、クライアントがネームサービスへ直接接続する様にした方がより単純になるでしょう。

![フリーランスパターン](images/fig55.eps)

;The types of failure we aim to handle are server crashes and restarts, server busy looping, server overload, and network issues. To get reliability, we'll create a pool of name servers so if one crashes or goes away, clients can connect to another, and so on. In practice, two would be enough. But for the example, we'll assume the pool can be any size.

ここで想定する障害は、サーバーのクラッシュやリスタート、バグによるビジーループ、サーバー負荷、ネットワーク障害です。
信頼性を高める為に、複数のネームサーバーを複数配備する事で、1台のサーバーがクラッシュしてもクライアントは別のサーバーに接続することが出来ます。
実際には2台で十分でしょうが、この例では何台でも増やせるように設計します。

;In this architecture, a large set of clients connect to a small set of servers directly. The servers bind to their respective addresses. It's fundamentally different from a broker-based approach like Majordomo, where workers connect to the broker. Clients have a couple of options:

このアーキテクチャは、膨大なクライアント群が少数のサーバ群に対して直接接続を行い、サーバーは個別のアドレスをbindします。
これはワーカーがブローカーに接続するMajordomoの様なアーキテクチャと根本的に異なります。
クライアント側には幾つかの実装方法があります。

;* Use REQ sockets and the Lazy Pirate pattern. Easy, but would need some additional intelligence so clients don't stupidly try to reconnect to dead servers over and over.
;* Use DEALER sockets and blast out requests (which will be load balanced to all connected servers) until they get a reply. Effective, but not elegant.
;* Use ROUTER sockets so clients can address specific servers. But how does the client know the identity of the server sockets? Either the server has to ping the client first (complex), or the server has to use a hard-coded, fixed identity known to the client (nasty).

* REQソケットでものぐさ海賊パターンを利用します。これは簡単ですが落ちたサーバーに何度も再接続しないように工夫が必要です。
* DEALERソケットを利用し、応答が得られるまで各サーバーに対してリクエストを投げ続けます。上品な方法ではありませんが効果的です。
* ROUTERソケットを利用して特定のサーバーに接続します。しかしどうやってサーバーのソケットIDを知れば良いのでしょうか? いずれかのサーバーが最初にクライアントに対してPINGを送る複雑な方法と、サーバーに固定的なIDをハードコードするという気持ちの悪い方法があります。

;We'll develop each of these in the following subsections.

以下の節でそれぞれ方法を実装していきます。

### モデル1: 単純なリトライとフェイルオーバー
;So our menu appears to offer: simple, brutal, complex, or nasty. Let's start with simple and then work out the kinks. We take Lazy Pirate and rewrite it to work with multiple server endpoints.

私達の目の前には3種類の選択肢が提示されています。
単純な方法か、荒っぽいやり方か、複雑で面倒な方法です。
まずひねくれてない単純な方法で実装してみましょう。
というわけでものぐさ海賊パターンを複数のサーバーに対応するように書きなおします。

;Start one or several servers first, specifying a bind endpoint as the argument:

まず、引き数にエンドポイント名を指定して、1つ以上のサーバーを起動して下さい。

~~~ {caption="flserver1: フリーランスサーバー モデル1"}
include(examples/EXAMPLE_LANG/flserver1.EXAMPLE_EXT)
~~~

;Then start the client, specifying one or more connect endpoints as arguments:

続いて、1つ以上のエンドポイントを指定してクライアントを起動します。

~~~ {caption="flclient1: フリーランスクライアント モデル1"}
include(examples/EXAMPLE_LANG/flclient1.EXAMPLE_EXT)
~~~

;A sample run is:

以下のように実行します。

~~~
flserver1 tcp://*:5555 &
flserver1 tcp://*:5556 &
flclient1 tcp://localhost:5555 tcp://localhost:5556
~~~

;Although the basic approach is Lazy Pirate, the client aims to just get one successful reply. It has two techniques, depending on whether you are running a single server or multiple servers:

基本的にはものぐさ海賊パターンと同じですが、クライアントはただ一つの応答を得ることを目的としています。
プログラムは動作しているサーバー数に応じて2つに分岐しています。

;* With a single server, the client will retry several times, exactly as for Lazy Pirate.
;* With multiple servers, the client will try each server at most once until it's received a reply or has tried all servers.

* サーバーが1つの場合、クライアントはものぐさ海賊パターンと同様に何度かリトライを行います。
* サーバーが複数の場合、応答が得られるまで全てのサーバーに対してリトライを行います。

;This solves the main weakness of Lazy Pirate, namely that it could not fail over to backup or alternate servers.

ものぐさ海賊パターンにはバックアップサーバーにもつながらない場合に問題がありましたが、ここではこの欠点を解決しています。

;However, this design won't work well in a real application. If we're connecting many sockets and our primary name server is down, we're going to experience this painful timeout each time.

しかし、この設計にも欠点があります。
最初のサーバーがダウンしている場合、ユーザーは毎回痛みを伴うタイムアウトを待つことになります。

### モデル2: ショットガンをぶっ放せ
;Let's switch our client to using a DEALER socket. Our goal here is to make sure we get a reply back within the shortest possible time, no matter whether a particular server is up or down. Our client takes this approach:

それではDEALERソケットに切り替えてみましょう。
ここでの私達の目的は、一部のサーバーがダウンしてしたとして可能な限り素早く応答を得ることです。
クライアントは以下の方針で実装します。

;* We set things up, connecting to all servers.
;* When we have a request, we blast it out as many times as we have servers.
;* We wait for the first reply, and take that.
;* We ignore any other replies.

* 全てのサーバーに接続します。
* リクエストを行う際はサーバーに対してリクエストを何度も投げ続けます。
* 最初の応答が得られたらこれを読みます。
* 残りの応答は全て無視します。

;What will happen in practice is that when all servers are running, ØMQ will distribute the requests so that each server gets one request and sends one reply. When any server is offline and disconnected, ØMQ will distribute the requests to the remaining servers. So a server may in some cases get the same request more than once.

これを行うと何が起こるかというと、全てのサーバーが動作している場合はそれぞれのサーバーがリクエストを受け取り、応答を返します。
どれかのサーバーが落ちている時は、動作しているサーバーに対してリクエストが送信されます。
従って、サーバーは2度以上の重複したリクエストを受け取る可能性があります。

;What's more annoying for the client is that we'll get multiple replies back, but there's no guarantee we'll get a precise number of replies. Requests and replies can get lost (e.g., if the server crashes while processing a request).

クライアントにとって面倒なのは、返ってくる複数の応答を処理しなければならない事。
しかもリクエストと応答はサーバーのクラッシュなどが原因で失われてしまう可能性があるので、いくつ返ってくるかを予め知ることは出来ません。

;So we have to number requests and ignore any replies that don't match the request number. Our Model One server will work because it's an echo server, but coincidence is not a great basis for understanding. So we'll make a Model Two server that chews up the message and returns a correctly numbered reply with the content "OK". We'll use messages consisting of two parts: a sequence number and a body.

従って、クライアントは要求番号と一致しない応答を全て無視する必要があります。
echoサーバーではこのモデルの題材にふさわしくありませんので、違う動作を行うサーバーを実装してみます。
モデル2のサーバーは応答のメッセージを読み込み、要求番号と一致している事と「OK」というメッセージの本文を確認します。
つまり、この応答メッセージは「シーケンス番号」と「本文」の2つのフレームを含んでいます。

;Start one or more servers, specifying a bind endpoint each time:

バインドするエンドポイントを指定して1つ以上のサーバーを起動します。

~~~ {caption="flserver2: フリーランスサーバー モデル2"}
include(examples/EXAMPLE_LANG/flserver2.EXAMPLE_EXT)
~~~

;Then start the client, specifying the connect endpoints as arguments:

そして、接続するエンドポイントを引き数に指定してクライアントを起動します。

~~~ {caption="flclient2: フリーランスクライアント モデル2"}
include(examples/EXAMPLE_LANG/flclient2.EXAMPLE_EXT)
~~~

;Here are some things to note about the client implementation:

クライアントの実装について注意すべき点は以下の通りです。

;* The client is structured as a nice little class-based API that hides the dirty work of creating ØMQ contexts and sockets and talking to the server. That is, if a shotgun blast to the midriff can be called "talking".
;* The client will abandon the chase if it can't find any responsive server within a few seconds.
;* The client has to create a valid REP envelope, i.e., add an empty message frame to the front of the message.

* ØMQコンテキストを作成する汚れ仕事やソケット、およびサーバーとの通信は綺麗に構造化されたクラスベースのAPIにより隠蔽しています。
* 数秒間どのサーバーからも応答が無ければ、クライアントは応答を待つのを止めます。
* クライアントは、正しいREPエンベロープを作成する必要があります。例えばメッセージフレームの前に空のフレームを追加する事などです。

;The client performs 10,000 name resolution requests (fake ones, as our server does essentially nothing) and measures the average cost. On my test box, talking to one server, this requires about 60 microseconds. Talking to three servers, it takes about 80 microseconds.

クライアントで1万回の名前解決を実行し、平均コストを計測してみます。
私のテストマシンでは1台のサーバーと通信するのに60ミリ秒、3台のサーバーと通信すると80ミリ秒掛かりました。

;The pros and cons of our shotgun approach are:

このショットガン方式の利点と欠点は、

;* Pro: it is simple, easy to make and easy to understand.
;* Pro: it does the job of failover, and works rapidly, so long as there is at least one server running.
;* Con: it creates redundant network traffic.
;* Con: we can't prioritize our servers, i.e., Primary, then Secondary.
;* Con: the server can do at most one request at a time, period.

* 利点: そこそこ単純で理解しやすいです。
* 利点: フェイルオーバーが機能し、少なくとも1台のサーバーが動作していれば迅速に動作します。。
* 欠点: 無駄なネットワークトラフィックが発生します。
* 欠点: プライマリーやセカンダリなど、サーバーの優先順位を決めることが出来ません。
* 欠点: ひとつのリクエストに対して全てのサーバーが処理を行う必要があります。

### モデル3: 複雑で面倒な方法
;The shotgun approach seems too good to be true. Let's be scientific and work through all the alternatives. We're going to explore the complex/nasty option, even if it's only to finally realize that we preferred brutal. Ah, the story of my life.

ショットガンをぶっ放すのがとても良い手段であることは真実です。
しかし全ての代替案について検討してみるのが科学というものです。
私達はこれから更に複雑で面倒な選択肢を提案しますが最終的にショットガンをぶっ放すのが望ましいと気がつくでしょう。
これから紹介するのは私が辿った道です。

;We can solve the main problems of the client by switching to a ROUTER socket. That lets us send requests to specific servers, avoid servers we know are dead, and in general be as smart as we want to be. We can also solve the main problem of the server (single-threadedness) by switching to a ROUTER socket.

主な問題はROUTERソケットに置き換えることで解決可能です。
クライアントは落ちているサーバーを予め知っておきリクエストを避ける方が一般的にスマートな方法でしょう。
そしてROUTERソケットに置き換える事でサーバーがシングルスレッドっぽくなる問題を解決できます。

;But doing ROUTER to ROUTER between two anonymous sockets (which haven't set an identity) is not possible. Both sides generate an identity (for the other peer) only when they receive a first message, and thus neither can talk to the other until it has first received a message. The only way out of this conundrum is to cheat, and use hard-coded identities in one direction. The proper way to cheat, in a client/server case, is to let the client "know" the identity of the server. Doing it the other way around would be insane, on top of complex and nasty, because any number of clients should be able to arise independently. Insane, complex, and nasty are great attributes for a genocidal dictator, but terrible ones for software.

しかし、IDの設定されていない匿名な2つのROUTERソケット同士で通信を行うことは出来ません。
最初のメッセージを受け取る際に両側で接続相手のIDを生成すれば良いのですが、IDが無いので最初のメッセージを受け取る事が出来ません。
この難問を解決する唯一の方法はカンニングです。つまりIDをハードコーディングするしかありません。
クライアント・サーバーモデルにおけるカンニングの正しい方法は、クライアントがサーバーのIDを知っていることにすることです。
他の方法もありますが複雑で厄介なのでやめたほうが良いでしょう。クライアントは何台立ち上がるか判らないからです。
愚かで、複雑で、厄介な事をするのは暴君の特徴ですが、恐ろしいことにソフトウェアにも当てはまります。

;Rather than invent yet another concept to manage, we'll use the connection endpoint as identity. This is a unique string on which both sides can agree without more prior knowledge than they already have for the shotgun model. It's a sneaky and effective way to connect two ROUTER sockets.

管理を行うための新しい概念を発明するのではなく、接続エンドポイントをIDとして利用します。
エンドポイントは両者が事前知識なしに合意できるユニークな文字列です。
これは2つのROUTERソケットを接続するための卑劣かつ有効な方法です。

;Remember how ØMQ identities work. The server ROUTER socket sets an identity before it binds its socket. When a client connects, they do a little handshake to exchange identities, before either side sends a real message. The client ROUTER socket, having not set an identity, sends a null identity to the server. The server generates a random UUID to designate the client for its own use. The server sends its identity (which we've agreed is going to be an endpoint string) to the client.

ØMQのIDがどの様に利用されるかを思い出して下さい。
サーバーのROUTERソケットはソケットをbindする前にIDを設定します。
クライアントが接続した際、メッセージをやりとりする前にちょっとしたハンドシェイクを行いIDを交換します。
クライアント側のROUTERソケットはIDを設定せず、空のIDで送信します。
そしてサーバーはランダムなUUIDを生成してクライアントに送信します。

;This means that our client can route a message to the server (i.e., send on its ROUTER socket, specifying the server endpoint as identity) as soon as the connection is established. That's not immediately after doing a zmq_connect(), but some random time thereafter. Herein lies one problem: we don't know when the server will actually be available and complete its connection handshake. If the server is online, it could be after a few milliseconds. If the server is down and the sysadmin is out to lunch, it could be an hour from now.

これはクライアントがメッセージをサーバーにルーティングできる事を意味します。
IDとしてサーバーのエンドポイントを指定すると直ちに接続が確立します。
それは正確には`zmq_connect()`を実行した直後ではありませんがしばらく経てば接続されます。
ここに問題があります。私達はサーバーへの接続が完了する正確なタイミングを知ることが出来ません。
もしサーバーがオンラインであれば数ミリ秒で接続は完了するでしょうが、サーバーが落ちていてシステム管理者がお昼ごはんを食べていれば1時間ほどかかってしまうでしょう。

;There's a small paradox here. We need to know when servers become connected and available for work. In the Freelance pattern, unlike the broker-based patterns we saw earlier in this chapter, servers are silent until spoken to. Thus we can't talk to a server until it's told us it's online, which it can't do until we've asked it.

ここにちょっとしたパラドックスがあります。
私達はサーバーへの接続が確立するタイミングを知る必要がありますが、これまで見てきたようにフリーランスパターンではサーバーと通信してみるまでサーバーがオンラインかどうかを知ることが出来ません。

;My solution is to mix in a little of the shotgun approach from model 2, meaning we'll fire (harmless) shots at anything we can, and if anything moves, we know it's alive. We're not going to fire real requests, but rather a kind of ping-pong heartbeat.

そこで私はモデル2で利用したショットガンの方法を組み合わせてこの問題を解決しました。
このある意味無害なショットを撃つことで、クライアントはサーバーの変化を知ることが出来ます。
これには実際のリクエストを送るのではなくハートビートによるPING-PONGを行って確認を行います。

;This brings us to the realm of protocols again, so here's a short spec that defines how a Freelance client and server exchange ping-pong commands and request-reply commands.

またプロトコルの話になりましたので、[フリーランスクライアントがサーバーとPING-PONGコマンドやリクエスト・応答をやりとりする為の短い仕様](http://rfc.zeromq.org/spec:10)を用意しました。

;It is short and sweet to implement as a server. Here's our echo server, Model Three, now speaking FLP:

サーバー側の実装は短くて良い感じです。
これをFLPプロトコルと呼んでいます。

~~~ {caption="flserver3: フリーランスサーバー モデル3"}
include(examples/EXAMPLE_LANG/flserver3.EXAMPLE_EXT)
~~~

;The Freelance client, however, has gotten large. For clarity, it's split into an example application and a class that does the hard work. Here's the top-level application:

こちらがフリーランスクライアントですが大きくなってしまいましたのでクラスに分離しました。
こちらがメインプログラムです。

~~~ {caption="flclient3: フリーランスクライアント モデル3"}
include(examples/EXAMPLE_LANG/flclient3.EXAMPLE_EXT)
~~~

;And here, almost as complex and large as the Majordomo broker, is the client API class:

そしてこちらがMajordomoブローカーと同じくらい巨大で複雑になってしまったクライアントAPIクラスのコードです。

~~~ {caption="flcliapi: フリーランスクライアントAPI"}
include(examples/EXAMPLE_LANG/flcliapi.EXAMPLE_EXT)
~~~

;This API implementation is fairly sophisticated and uses a couple of techniques that we've not seen before.

このAPIの実装はこれまでに紹介していない幾つかのテクニックを利用しています。

;* Multithreaded API: the client API consists of two parts, a synchronous flcliapi class that runs in the application thread, and an asynchronous agent class that runs as a background thread. Remember how ØMQ makes it easy to create multithreaded apps. The flcliapi and agent classes talk to each other with messages over an inproc socket. All ØMQ aspects (such as creating and destroying a context) are hidden in the API. The agent in effect acts like a mini-broker, talking to servers in the background, so that when we make a request, it can make a best effort to reach a server it believes is available.
;* Tickless poll timer: in previous poll loops we always used a fixed tick interval, e.g., 1 second, which is simple enough but not excellent on power-sensitive clients (such as notebooks or mobile phones), where waking the CPU costs power. For fun, and to help save the planet, the agent uses a tickless timer, which calculates the poll delay based on the next timeout we're expecting. A proper implementation would keep an ordered list of timeouts. We just check all timeouts and calculate the poll delay until the next one.

* マルチスレッドAPI: クライアントAPIは2つの部分から構成されています。アプリケーションから同期的に呼び出されるflcliapiクラスとバックグラウンドで非同期に実行されるagentクラスです。ØMQはマルチスレッドアプリケーションを簡単に作成できると説明したことを思い出して下さい。flcliapiクラスとagentクラスはお互いにプロセス内通信を行っています。ØMQに関する操作(コンテキストの生成や破棄など)はAPIの中に隠蔽しています。agentはバックグラウンドでサーバーと通信しリクエストを行う際に有効なな接続先を選択できるようなちょっとしたブローカーのような役割を持っています。

* Ticklessタイマー: これまで見てきたポーリングループでは1秒程度の固定のタイムアウト間隔を利用してきました。これは単純ですがタブレットやスマートフォンなどの非力なクライアントではCPUコストを消費してしまうので最適ではありません。地球を救うためにagentではTicklessタイマーを利用しましょう。Ticklessタイマーは期待するタイムアウト値に基づいてポーリング時間を計算します。一般的な実装ではタイムアウトの順序リストを保持し、ポーリング時間を計算します。

## まとめ
;In this chapter, we've seen a variety of reliable request-reply mechanisms, each with certain costs and benefits. The example code is largely ready for real use, though it is not optimized. Of all the different patterns, the two that stand out for production use are the Majordomo pattern, for broker-based reliability, and the Freelance pattern, for brokerless reliability.

この章では、リクエスト・応答パターンに様々な信頼性を持たせる方法を見てきました。
サンプルコードは最適化されていませんが、十分実用に使えるレベルです。
なにより対照的なのは、ブローカーに信頼性持たせるMajordomoパターンとブローカーの無いフリーランスパターンです。

