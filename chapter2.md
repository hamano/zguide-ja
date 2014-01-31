# ソケットとパターン
;In Chapter 1 - Basics we took ØMQ for a drive, with some basic examples of the main ØMQ patterns: request-reply, pub-sub, and pipeline. In this chapter, we're going to get our hands dirty and start to learn how to use these tools in real programs.

第1章「基礎」ではØMQの主要なパターンである「リクエスト・応答」、「pub-sub」、「パイプライン」などの基本的なサンプルコードを見てきました。
この章では実際のプログラムでこれらのパターンをどの様に利用するかを手を動かしながら学んで行きましょう。

;We'll cover:

この章では以下の内容を学んでいきます。

;* How to create and work with ØMQ sockets.
;* How to send and receive messages on sockets.
;* How to build your apps around ØMQ's asynchronous I/O model.
;* How to handle multiple sockets in one thread.
;* How to handle fatal and nonfatal errors properly.
;* How to handle interrupt signals like Ctrl-C.
;* How to shut down a ØMQ application cleanly.
;* How to check a ØMQ application for memory leaks.
;* How to send and receive multipart messages.
;* How to forward messages across networks.
;* How to build a simple message queuing broker.
;* How to write multithreaded applications with ØMQ.
;* How to use ØMQ to signal between threads.
;* How to use ØMQ to coordinate a network of nodes.
;* How to create and use message envelopes for pub-sub.
;* Using the HWM (high-water mark) to protect against memory overflows.

* ØMQソケットを生成して、動作させる方法
* ØMQソケットを経由してメッセージを送受信する方法
* ØMQの非同期I/Oモデルでアプリケーションを開発する方法
* 1スレッドで複数のソケットで扱う方法
* 致命的、致命的でないエラーを適切に処理する方法
* Ctrl-Cの様な割り込みシグナルを処理する方法
* ØMQアプリケーションを正しく終了させる方法
* ØMQアプリケーションでメモリリークチェックを行う方法
* マルチパートメッセージを送受信する方法
* 別のネットワークへメッセージを転送する方法
* 簡易メッセージキューブローカーの作成方法
* ØMQでマルチスレッドアプリケーションを作る方法
* スレッド間でシグナルを利用する方法
* ØMQでネットワークのノードを連携する方法
* pub-subパターンにおけるメッセージエンベローブの作成と利用方法
* HWM(満杯マーク)を使ってメモリ溢れを防ぐ方法

## ソケットAPI
;To be perfectly honest, ØMQ does a kind of switch-and-bait on you, for which we don't apologize. It's for your own good and it hurts us more than it hurts you. ØMQ presents a familiar socket-based API, which requires great effort for us to hide a bunch of message-processing engines. However, the result will slowly fix your world view about how to design and write distributed software.

正直に言うと、ØMQには囮商法の様な所があるかもしれませんが謝罪はしません。
その痛みはこれまでの痛みよりも良性の痛みだからです。
私達がメッセージ処理エンジンの多くを隠蔽する事に尽力したことにより、ØMQは親しみやすいソケットベースのAPIを提供しています。
しかしその結果、分散ソフトウェアの実装や設計方法に関するあなたの考え方を変える必要があるかもしれません。

;Sockets are the de facto standard API for network programming, as well as being useful for stopping your eyes from falling onto your cheeks. One thing that makes ØMQ especially tasty to developers is that it uses sockets and messages instead of some other arbitrary set of concepts. Kudos to Martin Sustrik for pulling this off.
;It turns "Message Oriented Middleware", a phrase guaranteed to send the whole room off to Catatonia, into "Extra Spicy Sockets!", which leaves us with a strange craving for pizza and a desire to know more.

ソケットAPIはネットワークプログラミングの事実上の標準というだけでなく、目が飛び出るほど便利です。
開発者にとってØMQの特に魅力的なところは、他の別の概念の代わりにソケットとメッセージを利用したという所です。
これについてはMartin Sustrikに賞賛を送りたいと思います。
; [TODO]

;Like a favorite dish, ØMQ sockets are easy to digest. Sockets have a life in four parts, just like BSD sockets:

大好きな料理と同じように、ØMQを飲み込むのは簡単です。
ØMQソケットの操作はBSDソケットとまったく同じように4つに分類する事が出来ます。

;* Creating and destroying sockets, which go together to form a karmic circle of socket life (see zmq_socket(), zmq_close()).
;* Configuring sockets by setting options on them and checking them if necessary (see zmq_setsockopt(), zmq_getsockopt()).
;* Plugging sockets into the network topology by creating ØMQ connections to and from them (see zmq_bind(), zmq_connect()).
;* Using the sockets to carry data by writing and receiving messages on them (see zmq_send(), zmq_recv()).

* ソケットの生成と開放。これはソケットの人生と責任範囲を示しています。(`zmq_socket()`, `zmq_close()`)
* 必要に応じてソケットオプションの取得や設定を行います。(`zmq_setsockopt()`, `zmq_getsockopt()`)
* ネットワークトポロジーにソケットを接続したり、待ち受けを行います。(`zmq_bind()`, `zmq_connect()`)
* ソケットを利用してメッセージの送受信を行います。(`zmq_send()`, `zmq_recv()`)

;Note that sockets are always void pointers, and messages (which we'll come to very soon) are structures. So in C you pass sockets as-such, but you pass addresses of messages in all functions that work with messages, like zmq_send() and zmq_recv(). As a mnemonic, realize that "in ØMQ, all your sockets are belong to us", but messages are things you actually own in your code.

ソケットは常にvoidポインタであり、メッセージは構造体であることに注意してください。[^1]
つまり、C言語ではソケットをそのまま渡しますが、`zmq_send()`や`zmq_recv()`はメッセージ構造体のポインタを渡して動作します。
覚え方としては、「ソケットは私達の所有物である」が、「メッセージはあなたのコードの所有物である」と言えます。

[^1]: 訳注: メッセージ構造体は、古いAPIであるzmq_msg_send() や zmq_msg_recv() に関しての説明だと思われる。

;Creating, destroying, and configuring sockets works as you'd expect for any object. But remember that ØMQ is an asynchronous, elastic fabric. This has some impact on how we plug sockets into the network topology and how we use the sockets after that.

ソケットの生成や破棄や設定はあなたの期待通りに動作します。
ただし、ØMQは柔軟に非同期で動作することを覚えておいて下さい。
これはネットワークトポロジーへの接続方法や、ソケットの扱い方にいくらかの影響を与えます。

### ソケットをトポロジーに接続する
;To create a connection between two nodes, you use zmq_bind() in one node and zmq_connect() in the other. As a general rule of thumb, the node that does zmq_bind() is a "server", sitting on a well-known network address, and the node which does zmq_connect() is a "client", with unknown or arbitrary network addresses. Thus we say that we "bind a socket to an endpoint" and "connect a socket to an endpoint", the endpoint being that well-known network address.

2つのノード間でコネクションを作成するためには、片方のノードで`zmq_bind()`を呼び、もう片方で`zmq_connect()`を呼び出します。
一般則では、`zmq_bind()`したノードは「サーバー」と呼ばれ、公開されたネットワークアドレスが設定されています。一方、`zmq_connect()`を行うノードは「クライアント」と呼ばれ、動的なネットワークアドレスであっても構いません。
従って私達は、「エンドポイントとしてソケットをバインドする」とか「ソケットをエンドポイントに接続する」という様な言い方をします。
エンドポイントは公開されたネットワークアドレスになるでしょう。

;ØMQ connections are somewhat different from classic TCP connections. The main notable differences are:

ØMQのコネクションは、古典的なTCPコネクションとは異なる点が幾つかあります。
主要な違いは以下の通りです。

;* They go across an arbitrary transport (inproc, ipc, tcp, pgm, or epgm). See zmq_inproc(), zmq_ipc(), zmq_tcp(), zmq_pgm(), and zmq_epgm().
;* One socket may have many outgoing and many incoming connections.
;* There is no zmq_accept() method. When a socket is bound to an endpoint it automatically starts accepting connections.
;* The network connection itself happens in the background, and ØMQ will automatically reconnect if the network connection is broken (e.g., if the peer disappears and then comes back).
;* Your application code cannot work with these connections directly; they are encapsulated under the socket.

 * ØMQはプロセス内通信、プロセス間通信、TCP、pgm, epgmなどの様々な通信方式を利用できます。(詳しくは`zmq_inproc()`, `zmq_ipc()`, `zmq_tcp()`, `zmq_pgm()`, `zmq_epgm()`のmanページを参照して下さい。)
 * 一つのソケットで複数の送受信コネクションを扱うことが出来ます。
 * `zmq_accept()`という関数は存在しません。ソケットがエンドポイントとしてバインドを行ったら、自動的に接続の受け付けを開始します。
 * ネットワークコネクションはバックグラウンドで処理されます。そしてもし接続が切断された場合は自動的に再接続を行います。(接続相手が復旧した場合)
 * アプリケーションから直接コネクションを触ることは出来ません。これらはソケットの中に隠蔽されています。

;Many architectures follow some kind of client/server model, where the server is the component that is most static, and the clients are the components that are most dynamic, i.e., they come and go the most. There are sometimes issues of addressing: servers will be visible to clients, but not necessarily vice versa. So mostly it's obvious which node should be doing zmq_bind() (the server) and which should be doing zmq_connect() (the client). It also depends on the kind of sockets you're using, with some exceptions for unusual network architectures. We'll look at socket types later.

多くのアーキテクチャでは、いわゆるクライアント・サーバーモデルに従っており、サーバーは静的なコンポーネント、クライアントは動的に増減するコンポーネントとして構成されています。
アドレッシングの問題として、一般的にサーバーのアドレスはクライアントに公開されている必要がありますが、その逆は必要ありません。
ですので、どちらのノードが`zmq_bind()`を呼び出し、どちらのノードが`zmq_connect()`を呼び出すべきかどうかは殆どの場合明らかです。
これは幾つかの例外的なネットワークアーキテクチャを除いて、どのソケット種別を利用するかどうかにも関連してきます。ソケット種別については後で説明します。

;Now, imagine we start the client before we start the server. In traditional networking, we get a big red Fail flag. But ØMQ lets us start and stop pieces arbitrarily. As soon as the client node does zmq_connect(), the connection exists and that node can start to write messages to the socket. At some stage (hopefully before messages queue up so much that they start to get discarded, or the client blocks), the server comes alive, does a zmq_bind(), and ØMQ starts to deliver messages.

さて、サーバーを起動する前にクライアントを起動するような状況を想像してみましょう。伝統的なネットワークであれば明確なエラーが発生します。
一方ØMQは部品を一時的に停止して、再開することが出来ます。
クライアントノードが`zmq_connect()`を呼び出すと直ぐに接続を行い、メッセージをソケットに書き込み出来るようになります。
サーバーが起動し、`zmq_bind()`が行われた段階でØMQはメッセージを配送します。

;A server node can bind to many endpoints (that is, a combination of protocol and address) and it can do this using a single socket. This means it will accept connections across different transports:

サーバーノードは一つのソケットに対して複数のエンドポイントをbindする事が出来ます。(複数のプロトコルやアドレスを組み合わせる事も可能)
これは異なる通信方式のネットワークを横断して接続を待ち受けることが出来るという事です。

~~~ {language="C"}
zmq_bind (socket, "tcp://*:5555");
zmq_bind (socket, "tcp://*:9999");
zmq_bind (socket, "inproc://somename");
~~~

;[TODO]With most transports, you cannot bind to the same endpoint twice, unlike for example in UDP. The ipc transport does, however, let one process bind to an endpoint already used by a first process. It's meant to allow a process to recover after a crash.

UDPとは異なり、殆どの通信方式では同じエンドポイントを2度バインドする事は出来ません。
IPC通信方式ではこれを行うことができますが、最初にbindを行ったプロセスのソケットは無効になります。これはプロセスのクラッシュから回復する為のものです。

;Although ØMQ tries to be neutral about which side binds and which side connects, there are differences. We'll see these in more detail later. The upshot is that you should usually think in terms of "servers" as static parts of your topology that bind to more or less fixed endpoints, and "clients" as dynamic parts that come and go and connect to these endpoints. Then, design your application around this model.
;[TODO]The chances that it will "just work" are much better like that.

とはいえ、ØMQはbindする側と接続する側について中立であろうとする事に大きな特徴があります。後でもっと詳しく説明しますが結論だけ言うと、
通常「サーバー」と聞くと、トポロジーの静的な部品として位置づけられる固定的なエンドポイントと考えます。
また、「クライアント」と聞くと、動的に増減する部品としてエンドポイントに接続しに来ます。
多くの場合このモデルに基づいてアプリケーションを設計されるでしょう。

;Sockets have types. The socket type defines the semantics of the socket, its policies for routing messages inwards and outwards, queuing, etc. You can connect certain types of socket together, e.g., a publisher socket and a subscriber socket. Sockets work together in "messaging patterns". We'll look at this in more detail later.

ソケットには幾つかの種類があります。
ソケット種別はソケットの役割を定めたものであり、メッセージのルーティングや内側や外側でキューイングしたりする際のポリシーです。
ソケットは例えばパブリッシャーソケットとサブスクライバーソケットの様に、特定のソケット種別との組み合わせで接続することが出来ます。
また、ソケットは「メッセージングパターン」との組み合わせで機能します。
これについては後ほど詳しく見ていきます。

;It's the ability to connect sockets in these different ways that gives ØMQ its basic power as a message queuing system. There are layers on top of this, such as proxies, which we'll get to later. But essentially, with ØMQ you define your network architecture by plugging pieces together like a child's construction toy.

異なる方法でソケットを接続するメッセージキューシステムこそがØMQの基本的な能力です。
あとで出てきますが、上位レイヤに位置するプロキシー様なものがあります。
しかしØMQの本質はレゴ・ブロックの様に部品を組み合わせることでネットワークアーキテクチャを構築できるという事です。

### メッセージの送受信
;To send and receive messages you use the zmq_msg_send() and zmq_msg_recv() methods. The names are conventional, but ØMQ's I/O model is different enough from the classic TCP model that you will need time to get your head around it.

メッセージの送受信を行うには、`zmq_msg_send()`関数と`zmq_msg_recv()`関数を利用します。慣習的な名前ではありますが、ØMQのI/Oモデルは古典的なTCPのものとは異なっている事を念頭に置いておく必要があります。

![TCPソケットは1対1に接続します](images/fig9.eps)

;Let's look at the main differences between TCP sockets and ØMQ sockets when it comes to working with data:

それでは、データを処理する際のTCPソケットとØMQソケットの主な違いを見て行きましょう。

;* ØMQ sockets carry messages, like UDP, rather than a stream of bytes as TCP does. A ØMQ message is length-specified binary data. We'll come to messages shortly; their design is optimized for performance and so a little tricky.
;* ØMQ sockets do their I/O in a background thread. This means that messages arrive in local input queues and are sent from local output queues, no matter what your application is busy doing.
;* ØMQ sockets have one-to-N routing behavior built-in, according to the socket type.

;* ØMQはTCPのデータストリームというよりも、UDPの様にメッセージを転送します。ØMQメッセージはサイズが指定されたバイナリデータです。メッセージが即座に転送されるよう、パフォーマンスに最適した設計を行っているため若干トリッキーです。
;* ØMQソケットはバックグラウンドスレッドでI/O処理を行います。これはアプリケーションがビジー状態であるかどうかに関わらず、ローカルキューのメッセージが処理されるという事を意味します。
;* ØMQソケットはソケット種別に応じたN対1のルーティング機能が組み込まれています。

;The zmq_send() method does not actually send the message to the socket connection(s). It queues the message so that the I/O thread can send it asynchronously. It does not block except in some exception cases. So the message is not necessarily sent when zmq_send() returns to your application.

`zmq_send()`関数を呼んだ時、実際にメッセージが送出されるわけではありません。
それはキューに入れられ、I/Oスレッドによって非同期に送信されます。
これは幾つか例外を除いてブロックされることはありません。
ですので`zmq_send()`からアプリケーションの処理に戻ってきた時、メッセージは必ずしも送信されていないと思っていて下さい。

### ユニキャストの通信方式
;ØMQ provides a set of unicast transports (inproc, ipc, and tcp) and multicast transports (epgm, pgm). Multicast is an advanced technique that we'll come to later. Don't even start using it unless you know that your fan-out ratios will make 1-to-N unicast impossible.

ØMQはユニキャスト通信方式(inproc, ipc, tcp)とマルチキャスト通信方式(epgm, pgm)に対応しています。マルチキャストは高度なテクニックなので後で説明します。
ファンアウト比の限界が分からないのに1対Nのユニキャストを使い始めるのは止めて下さい。

;For most common cases, use tcp, which is a disconnected TCP transport. It is elastic, portable, and fast enough for most cases. We call this disconnected because ØMQ's tcp transport doesn't require that the endpoint exists before you connect to it. Clients and servers can connect and bind at any time, can go and come back, and it remains transparent to applications.

最も一般的なケースでは、非接続性のTCP通信方式を使用します。
この方式は柔軟性と移植性に優れていて、多くのケースで十分高速です。
なぜ私達がこれを「非接続性」と呼ぶかと言うと、ØMQのTCP通信方式は接続先のエンドポイントが存在していなくても構わないからです。
クライアントとサーバーはいつでも接続とbindを行うことが可能で、それが可能になった時点でアプリケーションからは透過的に接続が確立します。

;The inter-process ipc transport is disconnected, like tcp. It has one limitation: it does not yet work on Windows. By convention we use endpoint names with an ".ipc" extension to avoid potential conflict with other file names. On UNIX systems, if you use ipc endpoints you need to create these with appropriate permissions otherwise they may not be shareable between processes running under different user IDs. You must also make sure all processes can access the files, e.g., by running in the same working directory.

プロセス間通信はTCPと同様に非接続性の通信方式です。
この方式は今のところWindowsで動作しないという制限があります。
慣例として、エンドポイント名に「.ipc」という拡張子を付けることで既存のファイルと競合することを避けています。
UNIXファイルシステムでは、IPCエンドポイントに適切なパーミッションが設定されている必要があります。そうしなければ異なるユーザーIDで動作しているプロセス間でIPCエンドポイントを共有できません。ですのでこれらのプロセスからIPCファイルにアクセス出来る必要があります。

;The inter-thread transport, inproc, is a connected signaling transport. It is much faster than tcp or ipc. This transport has a specific limitation compared to tpc and icp: the server must issue a bind before any client issues a connect. This is something future versions of ØMQ may fix, but at present this defines how you use inproc sockets. We create and bind one socket and start the child threads, which create and connect the other sockets.

スレッド間通信やプロセス内通信は、接続性のある通信方式です。
これはTCPやIPCよりはるかに高速です。
この通信方式はTCPやIPCと比べて特別な制限があります。
サーバーはクライアントが接続しにくるより前にbindしていなければなりません。
これは、将来のバージョンで改善されるかもしれませんが、現時点ではこういう制限があります。
まず、ソケットをbindしてから子スレッドを作成し接続を行って下さい。

### ØMQは中立キャリアではありません
;A common question that newcomers to ØMQ ask (it's one I've asked myself) is, "how do I write an XYZ server in ØMQ?" For example, "how do I write an HTTP server in ØMQ?" The implication is that if we use normal sockets to carry HTTP requests and responses, we should be able to use ØMQ sockets to do the same, only much faster and better.

初心者からのよくある質問に、「ØMQで〇〇サーバーをどうやって作ればよいですか?」例えば「ØMQでHTTPサーバーをどうやって作るの?」という質問を受けます。
恐らく質問者は、普通のTCPソケットでHTTPリクエストとレスポンスを転送できるのだから、ØMQソケットを利用して同じ事をより良く実現できるのではないか、と考えているのでしょう。

;The answer used to be "this is not how it works". ØMQ is not a neutral carrier: it imposes a framing on the transport protocols it uses. This framing is not compatible with existing protocols, which tend to use their own framing. For example, compare an HTTP request and a ØMQ request, both over TCP/IP.

答えは、「その様な事は出来ない」です。ØMQは中立キャリアではありません。
ØMQは転送プロトコルにフレーミングを強要します。
既存のプロトコルは独自のフレーミングを利用しようとしますが、ØMQのフレーミングとは互換性がありません。
例として、HTTPリクエストとØMQリクエストを比較してみましょう。
両者ともTCP上のプロトコルです。

![HTTPの通信データ](images/fig10.eps)

;The HTTP request uses CR-LF as its simplest framing delimiter, whereas ØMQ uses a length-specified frame. So you could write an HTTP-like protocol using ØMQ, using for example the request-reply socket pattern. But it would not be HTTP.

ØMQがフレームの長さを指定しているのに対し、HTTPリクエストはフレーミングの区切りにCR-LFを利用しています。
ですから、ØMQのリクエスト・応答ソケットパターンを利用してHTTPの様なプロトコルを実装したとしても、それはHTTPでは無いのです。

![ØMQの通信データ](images/fig11.eps)

;Since v3.3, however, ØMQ has a socket option called ZMQ_ROUTER_RAW that lets you read and write data without the ØMQ framing. You could use this to read and write proper HTTP requests and responses. Hardeep Singh contributed this change so that he could connect to Telnet servers from his ØMQ application. At time of writing this is still somewhat experimental, but it shows how ØMQ keeps evolving to solve new problems. Maybe the next patch will be yours.

ただしØMQのバージョン3.3以降、ØMQのフレーミングを利用せずソケットを読み書きすることが出来る、`ZMQ_ROUTER_RAW`というソケットオプションが追加されました。
これを利用して、厳密にHTTPリクエストを実装することは可能です。
Hardeep Singhさんのこの貢献により彼のØMQアプリケーションからTelnetサーバーに接続することを可能にしました。
これはまだ実験的なものですが、これはØMQが新しい問題を解決して進化し続けていることを示しています。次はパッチはあなたの書いたパッチがマージされるかもしれませんよ。

### I/Oスレッド
;We said that ØMQ does I/O in a background thread. One I/O thread (for all sockets) is sufficient for all but the most extreme applications. When you create a new context, it starts with one I/O thread. The general rule of thumb is to allow one I/O thread per gigabyte of data in or out per second. To raise the number of I/O threads, use the zmq_ctx_set() call before creating any sockets:

先ほど述べたようにØMQのI/Oはバックグラウンドで行います。
極端なアプリケーションを除いて、I/Oスレッドは一つで十分です。
新しいコンテキストを作成すると、一つのスレッドが起動します。
一般的な経験則で言うと、一つのスレッドで1秒間に数ギガバイトのデータを扱う事ができます。
I/Oスレッドの数を増やしたい場合、ソケットを生成する前に`zmq_ctx_set()`を呼び出します。

~~~
int io_threads = 4;
void *context = zmq_ctx_new ();
zmq_ctx_set (context, ZMQ_IO_THREADS, io_threads);
assert (zmq_ctx_get (context, ZMQ_IO_THREADS) == io_threads);
~~~

;We've seen that one socket can handle dozens, even thousands of connections at once. This has a fundamental impact on how you write applications. A traditional networked application has one process or one thread per remote connection, and that process or thread handles one socket. ØMQ lets you collapse this entire structure into a single process and then break it up as necessary for scaling.

これまで一つのソケットで数千のコネクションを同時に扱える事を見てきました。
これはあなたのアプリケーション開発に根本的な影響を与えます。
伝統的なネットワークアプリケーションは、一つのプロセス、もしくは一つのスレッド毎にコネクション持ち、ソケットを扱います。
ØMQを利用すると、全ての構造を一つのプロセスでやり遂げるので、スケーラビリティの壁を打ち破る事ができます。

;If you are using ØMQ for inter-thread communications only (i.e., a multithreaded application that does no external socket I/O) you can set the I/O threads to zero. It's not a significant optimization though, more of a curiosity.

例外的にスレッド間通信(例えば、マルチスレッドアプリケーションで外部とのI/Oソケットを持たない場合)のみを利用している場合にI/Oスレッドの数を0に設定することが出来ます。しかしこれは興味をそそるような重要な最適化ではありません。

## メッセージングパターン
;Underneath the brown paper wrapping of ØMQ's socket API lies the world of messaging patterns. If you have a background in enterprise messaging, or know UDP well, these will be vaguely familiar. But to most ØMQ newcomers, they are a surprise. We're so used to the TCP paradigm where a socket maps one-to-one to another node.

ØMQのソケットAPIの包み紙の底にはメッセージングパターンが横たわっています。
エンタープライズのメッセージング製品の経験があるか、もしくはUDPについてよく知っていればなんとなく解るでしょう。
しかし殆どのØMQの初心者はこの事に驚くでしょう。
彼らは既にソケットが1対1に別のノードに対応するTCPのパラダイムに慣れているからです。

;Let's recap briefly what ØMQ does for you. It delivers blobs of data (messages) to nodes, quickly and efficiently. You can map nodes to threads, processes, or nodes. ØMQ gives your applications a single socket API to work with, no matter what the actual transport (like in-process, inter-process, TCP, or multicast). It automatically reconnects to peers as they come and go. It queues messages at both sender and receiver, as needed. It manages these queues carefully to ensure processes don't run out of memory, overflowing to disk when appropriate. It handles socket errors. It does all I/O in background threads. It uses lock-free techniques for talking between nodes, so there are never locks, waits, semaphores, or deadlocks.

ØMQの動作について簡単に要約すると、ØMQはデータの塊(メッセージ)を効率良く迅速に転送します。
ノードをスレッド、プロセス、別ノードに対応付ける事が出来ます。
ØMQは様々な通信手段(プロセス内、プロセス間、TCP、マルチキャストなど)を扱う単一のソケットAPIを提供します。
接続相手が一時的に居なくなった場合に再接続を行います。
送信側と受信側の両方でメッセージを必要に応じてキューイングします。
メモリやディスクを食いつぶしたりしないように、キューを慎重に管理します。
ソケットのエラーを適切に処理します。
全てのI/Oはバックグラウンドのスレッドで処理されます。
ノード間の通信にはロック・フリーのテクニックが使われていますのでロックやセマフォ、デッドロックが発生しません。

;But cutting through that, it routes and queues messages according to precise recipes called patterns. It is these patterns that provide ØMQ's intelligence. They encapsulate our hard-earned experience of the best ways to distribute data and work. ØMQ's patterns are hard-coded but future versions may allow user-definable patterns.

通してみると、パターンと呼ばれる明確なレシピに従ってメッセージをキューイングしたりルーティングしている事が分ります。
これらのパターンによってØMQの知性が提供されます。
これらは、分散データ処理に関して私達が経験によって苦労して得た最良の方法をカプセル化したものです。
ØMQのパターンは現在ハードコーディングされていますが、将来的にはユーザー定義のパターンを定義出来るようにするつもりです。

;ØMQ patterns are implemented by pairs of sockets with matching types. In other words, to understand ØMQ patterns you need to understand socket types and how they work together. Mostly, this just takes study; there is little that is obvious at this level.

ØMQのパターンはソケット種別のペアによって実装されます。
言い換えると、ØMQのパターンを理解するためにはソケット種別とそれがどの様に連携して動作するかを理解する必要があります。
[TODO]

;The built-in core ØMQ patterns are:

ØMQに組み込まれている主要なパターンは、

;* Request-reply, which connects a set of clients to a set of services. This is a remote procedure call and task distribution pattern.
;* Pub-sub, which connects a set of publishers to a set of subscribers. This is a data distribution pattern.
;* Pipeline, which connects nodes in a fan-out/fan-in pattern that can have multiple steps and loops. This is a parallel task distribution and collection pattern.
;* Exclusive pair, which connects two sockets exclusively. This is a pattern for connecting two threads in a process, not to be confused with "normal" pairs of sockets.

* リクエスト・応答: 複数のクライアントが複数のサービスに接続します。RPC(リモート・プロシージャ・コール)パターンやタスク分散処理パターンと言います。
* Pub-sub: 複数のサブスクライバが複数のパブリッシャーに接続します。これはデータ分散処理パターンと言います。
* パイプライン: 複数の層やループを持つファン・アウト/ファン・インパターンでノードを接続します。これは並行タスク分散処理パターン、コレクションパターンと言います。
* 排他的ペア: 2つのソケットを排他的に接続します。これはプロセス内の2つのスレッドを接続するためのパターンです。**通常**のソケットペアと混同しないで下さい。

;We looked at the first three of these in Chapter 1 - Basics, and we'll see the exclusive pair pattern later in this chapter. The zmq_socket() man page is fairly clear about the patterns — it's worth reading several times until it starts to make sense. These are the socket combinations that are valid for a connect-bind pair (either side can bind):

第1章「基礎」で最初の3つは既に見てきました。
そして排他的ペアのパターンは後の章でやります。
`zmq_socket()`のmanページはパターンについて詳しく説明していますのでよく理解できるまで何度か読み返すだけの価値はあります。
以下は接続とbindを行う際に有効なソケットペアの組み合わせです。(どちら側でもbind出来ます)

; * PUB and SUB
; * REQ and REP
; * REQ and ROUTER
; * DEALER and REP
; * DEALER and ROUTER
; * DEALER and DEALER
; * ROUTER and ROUTER
; * PUSH and PULL
; * PAIR and PAIR

* PUBとSUB
* REQとREP
* REQとROUTER
* DEALERとREP
* DEALERとROUTER
* DEALERとDEALER
* ROUTERとROUTER
* PUSHとPULL
* PAIRとPAIR

;You'll also see references to XPUB and XSUB sockets, which we'll come to later (they're like raw versions of PUB and SUB). Any other combination will produce undocumented and unreliable results, and future versions of ØMQ will probably return errors if you try them. You can and will, of course, bridge other socket types via code, i.e., read from one socket type and write to another.

後ほど`XPUB`や`XSUB`というソケットも出てくるでしょう。これはPUBとSUBのrawソケットのような物です。これ以外の組み合わせはドキュメント化されていなかったり、信頼できない結果が得られます。将来的なバージョンでは正しくエラーが返ってくるようになるでしょう。
もちろん他のソケットタイプをブリッジして、一度ソケットから読み込んだメッセージを他のソケットに書き込むような事は可能です。

### ハイレベル・メッセージングパターン
;These four core patterns are cooked into ØMQ. They are part of the ØMQ API, implemented in the core C++ library, and are guaranteed to be available in all fine retail stores.

これらの主要なパターンがØMQで料理されます。
これらはØMQ APIの一部分であり、
コアC++ライブラリで実装され、全ての小売店で販売されるようになります。

;On top of those, we add high-level messaging patterns. We build these high-level patterns on top of ØMQ and implement them in whatever language we're using for our application. They are not part of the core library, do not come with the ØMQ package, and exist in their own space as part of the ØMQ community. For example the Majordomo pattern, which we explore in Chapter 4 - Reliable Request-Reply Patterns, sits in the GitHub Majordomo project in the ZeroMQ organization.

これら基本的なメッセージパターンの上に、ハイレベルなメッセージングパターンを追加する事が出来ます。
アプリケーションで利用している様々な言語でØMQの上にハイレベルなパターンを構築します。
これらはコア・ライブラリの一部ではありませんので、ØMQのパッケージには含まれていませんし、ØMQコミュニティで配布しているわけではありません。
例えばMajordomoパターンについては第4章の「信頼性のあるリクエスト・応答パターン」で詳しく解説しますが、これは別プロジェクトとしてGitHubでホスティングされています。

;One of the things we aim to provide you with in this book are a set of such high-level patterns, both small (how to handle messages sanely) and large (how to make a reliable pub-sub architecture).

この本の目的の一つは大小様々なハイレベルパターンを知る事で、メッセージを正しく処理し、信頼性のあるpub-subアーキテクチャを構築できるようにする為です。

### メッセージの処理
;The libzmq core library has in fact two APIs to send and receive messages. The zmq_send() and zmq_recv() methods that we've already seen and used are simple one-liners. We will use these often, but zmq_recv() is bad at dealing with arbitrary message sizes: it truncates messages to whatever buffer size you provide. So there's a second API that works with zmq_msg_t structures, with a richer but more difficult API:

libzmqのコアライブラリは、送受信を行う2つのAPIを持っています。
`zmq_send()`と`zmq_recv()`関数については既に簡単な使い方を見てきました。
私達は時々`zmq_recv()`を利用しますが、一定のバッファーサイズを超えたメッセージを切り捨てる為、任意のメッセージサイズを扱う際には都合が悪いことがあります。
ですので、zmq_msg_t構造体を渡す事の出来る、より高機能で複雑な2つ目のAPIが用意されています。

;* Initialise a message: zmq_msg_init(), zmq_msg_init_size(), zmq_msg_init_data().
;* Sending and receiving a message: zmq_msg_send(), zmq_msg_recv().
;* Release a message: zmq_msg_close().
;* Access message content: zmq_msg_data(), zmq_msg_size(), zmq_msg_more().
;* Work with message properties: zmq_msg_get(), zmq_msg_set().
;* Message manipulation: zmq_msg_copy(), zmq_msg_move().

* メッセージの初期化: `zmq_msg_init()`, `zmq_msg_init_size()`, `zmq_msg_init_data()`
* メッセージの受信: `zmq_msg_send()`, `zmq_msg_recv()`
* メッセージの開放: `zmq_msg_close()`
* メッセージデータへのアクセス: `zmq_msg_data()`, `zmq_msg_size()`, `zmq_msg_more()`
* メッセージプロパティの取得、設定: `zmq_msg_get()`, `zmq_msg_set()`
* メッセージ操作: `zmq_msg_copy()`, `zmq_msg_move()`

;On the wire, ØMQ messages are blobs of any size from zero upwards that fit in memory. You do your own serialization using protocol buffers, msgpack, JSON, or whatever else your applications need to speak. It's wise to choose a data representation that is portable, but you can make your own decisions about trade-offs.

通信経路上では、ØMQのメッセージは0から任意のサイズのデータとしてメモリに格納されています。
そしてprotocol buffersやmsgpack、JSON、あるいはあなたのアプリケーションで利用できる独自の方法でシリアライゼーションを行うことができます。
可搬性のあるデータ表現を選択する事は賢明な判断ですが、この決定にはトレードオフが伴うでしょう。

;In memory, ØMQ messages are zmq_msg_t structures (or classes depending on your language). Here are the basic ground rules for using ØMQ messages in C:

ØMQメッセージは`zmq_msg_t`構造体(利用している言語によってはクラス)でメモリに格納されています。以下はØMQメッセージをC言語で扱う上での基本原則です。

; * You create and pass around zmq_msg_t objects, not blocks of data.
; * To read a message, you use zmq_msg_init() to create an empty message, and then you pass that to zmq_msg_recv().
; * To write a message from new data, you use zmq_msg_init_size() to create a message and at the same time allocate a block of data of some size. You then fill that data using memcpy, and pass the message to zmq_msg_send().
; * To release (not destroy) a message, you call zmq_msg_close(). This drops a reference, and eventually ØMQ will destroy the message.
; * To access the message content, you use zmq_msg_data(). To know how much data the message contains, use zmq_msg_size().
; * Do not use zmq_msg_move(), zmq_msg_copy(), or zmq_msg_init_data() unless you read the man pages and know precisely why you need these.
; * After you pass a message to zmq_msg_send(), ØMQ will clear the message, i.e., set the size to zero. You cannot send the same message twice, and you cannot access the message data after sending it.
; * These rules don't apply if you use zmq_send() and zmq_recv(), to which you pass byte arrays, not message structures.

 * メッセージとは生成、もしくは受信した`zmq_msg_t`オブジェクトの事です。バイト配列ではありません。
 * メッセージを受信するには、まず`zmq_msg_init()`を呼び出して空のメッセージを生成し、`zmq_msg_recv()`に渡して受信する必要があります。
 * メッセージを送信するには、まず`zmq_msg_init_size()`を呼び出してデータと同サイズのメッセージオブジェクトを作成します。そして`memcpy()`などを利用してデータをメッセージオブジェクトにコピーし、`zmq_msg_send()`に渡して送信します。
 * メッセージオブジェクトを開放するには`zmq_msg_close()`を呼び出します。参照を開放し、ØMQは最終的にメッセージは破壊します。
 * メッセージの内容にアクセスするには`zmq_msg_data()`を利用します。メッセージのデータサイズを知りたい場合は`zmq_msg_size()`を呼び出します。
 * `zmq_msg_move()`, `zmq_msg_copy()`, `zmq_msg_init_data()`などの関数はmanページを読み、何故これが必要なのかはっきりと理解できるまで利用してはいけません。
 * `zmq_msg_send()`を読んでメッセージを送信すると、ØMQはメッセージオブジェクトを初期化します。具体的にはサイズが0になります。同じメッセージを2度送信することは出来ませんし、送信後のメッセージにアクセスする事は出来ません。
 * これらのルールは`zmq_send()`と`zmq_recv()`には当てはまりません。これらの関数はメッセージオブジェクトではなくバイト配列を受け取るからです。

;If you want to send the same message more than once, and it's sizable, create a second message, initialize it using zmq_msg_init(), and then use zmq_msg_copy() to create a copy of the first message. This does not copy the data but copies a reference. You can then send the message twice (or more, if you create more copies) and the message will only be finally destroyed when the last copy is sent or closed.

もしも同じメッセージを2度以上送信したい場合、2つ目のメッセージも`zmq_msg_init()`を呼び出して初期化し、`zmq_msg_copy()`を呼び出して1つ目のメッセージをコピーして下さい。これはデータそのものをコピーせず、参照をコピーします。これでメッセージを2度以上送信出来るようになり、最後のコピーが送信あるいはcloseされた場合にメッセージが開放されます。

;ØMQ also supports multipart messages, which let you send or receive a list of frames as a single on-the-wire message. This is widely used in real applications and we'll look at that later in this chapter and in Chapter 3 - Advanced Request-Reply Patterns.

ØMQは一つのメッセージに複数のフレームを含めて送受信を行う事が出来る、マルチパート・メッセージに対応しています。
これは実際のアプリケーションでよく使われるので、第3章の「リクエスト・応答パターンの応用」で説明します。

;Frames (also called "message parts" in the ØMQ reference manual pages) are the basic wire format for ØMQ messages. A frame is a length-specified block of data. The length can be zero upwards. If you've done any TCP programming you'll appreciate why frames are a useful answer to the question "how much data am I supposed to read of this network socket now?"

フレーム(ØMQのmanページで「message parts」とも呼ばれています)はØMQの基本的な転送フォーマットです。
フレームは長さが決められたバイト配列であり、0以上の長さを指定できます。
もしあなたがTCPプログラミングに慣れている場合、何故フレームが便利なのか理解できるはずです。
ネットワークソケットからどれくらいのサイズのデータが送られてくるか予め知ることができるからです。

;There is a wire-level protocol called ZMTP that defines how ØMQ reads and writes frames on a TCP connection. If you're interested in how this works, the spec is quite short.

ØMQがTCP接続上でフレームを読み書きする方法を定義した[ZMTPという転送プロトコル](http://rfc.zeromq.org/spec:15)があります。
この仕様はとても短いですので、もしこれに興味があれば読んでみて下さい。

;Originally, a ØMQ message was one frame, like UDP. We later extended this with multipart messages, which are quite simply series of frames with a "more" bit set to one, followed by one with that bit set to zero. The ØMQ API then lets you write messages with a "more" flag and when you read messages, it lets you check if there's "more".

元々、ØMQのメッセージはUDPの様に一つのフレームしか持っていませんでした。
私達は後々マルチパートメッセージを扱えるようにこれを拡張しました。
これはとても単純に一連のフレームが連続している場合はビット集合の「more」フラグをオンにします。
これにより、ØMQ APIはメッセージを受信する際に「more」フラグがあるかどうか確認する事ができます。

;In the low-level ØMQ API and the reference manual, therefore, there's some fuzziness about messages versus frames. So here's a useful lexicon:

低レベルAPIやマニュアルの中には、「メッセージ」と「フレーム」という言葉について幾つか曖昧な点があるのでここで整理しておきます。

;* A message can be one or more parts.
;* These parts are also called "frames".
;* Each part is a zmq_msg_t object.
;* You send and receive each part separately, in the low-level API.
;* Higher-level APIs provide wrappers to send entire multipart messages.

 * メッセージは一つ以上の部品で構成されます。
 * これらの部品はフレームと呼ばれます。
 * これらの部品はzmq_msg_tオブジェクトです。
 * 各部品は低レベルAPIを用いて別々に送受信することが出来ます。
 * 高レベルAPIではマルチパートメッセージをまとめて送信する事ができるラッパーを提供します。

;Some other things that are worth knowing about messages:

メッセージについて以下のことも知っておくと良いでしょう。

; * You may send zero-length messages, e.g., for sending a signal from one thread to another.
; * ØMQ guarantees to deliver all the parts (one or more) for a message, or none of them.
; * ØMQ does not send the message (single or multipart) right away, but at some indeterminate later time. A multipart message must therefore fit in memory.
; * A message (single or multipart) must fit in memory. If you want to send files of arbitrary sizes, you should break them into pieces and send each piece as separate single-part messages. Using multipart data will not reduce memory consumption.
; * You must call zmq_msg_close() when finished with a received message, in languages that don't automatically destroy objects when a scope closes. You don't call this method after sending a message.

 * 長さ0サイズのメッセージを送ることが可能です。(例えばノードから別のノードに通知を送りたい場合など)
 * ØMQはメッセージの部品を全て転送するか、全く送信しないかのどちらかであることを保証します。
 * メッセージは即座に送信されず、不確定なタイミングで送信されます。従ってマルチパートメッセージはメモリに収まらなければなりません。
 * メッセージはメモリに収まる必要があります。もし、あなたが巨大なファイルを送りたい場合それらを分割してシングルパートメッセージとして送信する必要があります。マルチパートメッセージを利用した所でメモリの使用量は変わりありません。
 * スコープが外れた時にオブジェクトを自動的に開放しない言語では、メッセージの受信が完了した際には`zmq_msg_close()`を呼び出す必要があります。メッセージを送信した後にこの関数を呼び出す必要はありません。

;And to be repetitive, do not use zmq_msg_init_data() yet. This is a zero-copy method and is guaranteed to create trouble for you. There are far more important things to learn about ØMQ before you start to worry about shaving off microseconds.

繰り返し言いますが、まだ`zmq_msg_init_data()`関数はまだ利用しないで下さい。
これはゼロコピーを行う手段であり、間違いなくあなたを悩ませるでしょう。
細かいことを気にする前に、ØMQについてもっと重要な事を学ぶ必要があります。

;This rich API can be tiresome to work with. The methods are optimized for performance, not simplicity. If you start using these you will almost definitely get them wrong until you've read the man pages with some care. So one of the main jobs of a good language binding is to wrap this API up in classes that are easier to use.

高レベルAPIを利用すると面倒なことが起きる場合があります。
この関数は、単純さよりもパフォーマンスに最適化されているからです。
注意深くmanページを読まずにこれらの関数を使用すると、間違いなく誤った使い方をしてしまうでしょう。
ですのでこれらのAPIを簡単に使えるようにラップしてやることですが言語バインディングの重要な仕事になります。

### 複数のソケットを処理する(Handling Multiple Sockets)
;In all the examples so far, the main loop of most examples has been:

これまでのサンプルコードでは、全てメインループで以下の処理を行っていました。

;1. Wait for message on socket.
;2. Process message.
;3. Repeat.

1. ソケットからのメッセージを待つ
2. メッセージを処理する
3. 繰り返し

;What if we want to read from multiple endpoints at the same time? The simplest way is to connect one socket to all the endpoints and get ØMQ to do the fan-in for us. This is legal if the remote endpoints are in the same pattern, but it would be wrong to connect a PULL socket to a PUB endpoint.

もし複数のエンドポイントから同時に受信を行いたい場合はどうしたら良いのでしょうか?最も単純な方法はファン・インとして全てのエンドポイントを一つのソケットで接続する方法です。
これはリモートのエンドポイントが同じパターンである場合に有効ですが、PULLソケットからPUBエンドポイントへと接続する場合に上手く行きません。

;To actually read from multiple sockets all at once, use zmq_poll(). An even better way might be to wrap zmq_poll() in a framework that turns it into a nice event-driven reactor, but it's significantly more work than we want to cover here.

正しく複数のソケットから同時に受信するためには`zmq_poll()`を利用します。
もっと良い方法は、`zmq_poll()`をラップしてイベントドリブンに反応するフレームワークを用いることだが、ここではそれについて取り上げません。

;Let's start with a dirty hack, partly for the fun of not doing it right, but mainly because it lets me show you how to do nonblocking socket reads. Here is a simple example of reading from two sockets using nonblocking reads. This rather confused program acts both as a subscriber to weather updates, and a worker for parallel tasks:

さて、やってはいけない例として泥臭いハックを見て行きましょう。
その目的は、非ブロッキングでソケットを読み込む方法を学ぶ為です。
この例では非ブロッキングで２つのソケットから読み込みを行う例を示します。
ややこしいですが、気象情報のサブスクライバーと並行処理のワーカーの両方の機能を持ったプログラムを例に使用します。

~~~ {caption="msreader: Multiple socket reader in C"}
// 複数のソケットから受信を行います
// この例では単純に受信ループを利用しています

#include "zhelpers.h"

int main (void)
{
    // Connect to task ventilator
    void *context = zmq_ctx_new ();
    void *receiver = zmq_socket (context, ZMQ_PULL);
    zmq_connect (receiver, "tcp://localhost:5557");

    // Connect to weather server
    void *subscriber = zmq_socket (context, ZMQ_SUB);
    zmq_connect (subscriber, "tcp://localhost:5556");
    zmq_setsockopt (subscriber, ZMQ_SUBSCRIBE, "10001 ", 6);

    // Process messages from both sockets
    // We prioritize traffic from the task ventilator
    while (1) {
        char msg [256];
        while (1) {
            int size = zmq_recv (receiver, msg, 255, ZMQ_DONTWAIT);
            if (size != -1) {
                // Process task
            }
            else
                break;
        }
        while (1) {
            int size = zmq_recv (subscriber, msg, 255, ZMQ_DONTWAIT);
            if (size != -1) {
                // Process weather update
            }
            else
                break;
        }
        // No activity, so sleep for 1 msec
        s_sleep (1);
    }
    zmq_close (receiver);
    zmq_close (subscriber);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

;The cost of this approach is some additional latency on the first message (the sleep at the end of the loop, when there are no waiting messages to process). This would be a problem in applications where submillisecond latency was vital. Also, you need to check the documentation for nanosleep() or whatever function you use to make sure it does not busy-loop.

この方法の欠点は、ループの最後にあるsleepによって一つ目のメッセージを読み込む前に遅延が発生してしまうことです。
これは、ミリ秒以上の遅延を許容しないアプリケーションで問題になるでしょう。
また、`nanosleep()`の様な関数を利用しても構いませんが、ビジーループが発生しないかどうか確認する必要があります。

;You can treat the sockets fairly by reading first from one, then the second rather than prioritizing them as we did in this example.

この例では、2つめのソケットよりも優先的に一つ目のソケットの読み込みが行われます。

;Now let's see the same senseless little application done right, using zmq_poll():

さて次は、同じようなアプリケーションで`zmq_poll()`を使う例を見て行きましょう。

~~~ {caption="mspoller: Multiple socket poller in C"}
// この例ではzmq_poll()を利用して複数のソケットから受信を行います

#include "zhelpers.h"

int main (void)
{
    // Connect to task ventilator
    void *context = zmq_ctx_new ();
    void *receiver = zmq_socket (context, ZMQ_PULL);
    zmq_connect (receiver, "tcp://localhost:5557");

    // Connect to weather server
    void *subscriber = zmq_socket (context, ZMQ_SUB);
    zmq_connect (subscriber, "tcp://localhost:5556");
    zmq_setsockopt (subscriber, ZMQ_SUBSCRIBE, "10001 ", 6);

    // Process messages from both sockets
    while (1) {
        char msg [256];
        zmq_pollitem_t items [] = {
            { receiver, 0, ZMQ_POLLIN, 0 },
            { subscriber, 0, ZMQ_POLLIN, 0 }
        };
        zmq_poll (items, 2, -1);
        if (items [0].revents & ZMQ_POLLIN) {
            int size = zmq_recv (receiver, msg, 255, 0);
            if (size != -1) {
                // Process task
            }
        }
        if (items [1].revents & ZMQ_POLLIN) {
            int size = zmq_recv (subscriber, msg, 255, 0);
            if (size != -1) {
                // Process weather update
            }
        }
    }
    zmq_close (subscriber);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

;The items structure has these four members:

`zmq_pollitem_t`構造体は４つのメンバ変数を持っています。

~~~
typedef struct {
    void *socket; // 0MQ socket to poll on
    int fd; // OR, native file handle to poll on
    short events; // Events to poll on
    short revents; // Events returned after poll
} zmq_pollitem_t;
~~~

### マルチパートメッセージ
;ØMQ lets us compose a message out of several frames, giving us a "multipart message". Realistic applications use multipart messages heavily, both for wrapping messages with address information and for simple serialization. We'll look at reply envelopes later.

ØMQは幾つかのフレームをまとめたマルチパートメッセージを扱うことが出来ます。
実際にはマルチパートメッセージを利用すると、宛先情報を付与して、シリアライズを行うため、処理が重くなります。
後ほど、応答エンベロープの詳細について見ていきます。

;What we'll learn now is simply how to blindly and safely read and write multipart messages in any application (such as a proxy) that needs to forward messages without inspecting them.

今から学ぶことは、単純にアプリケーションから安全にマルチパートメッセージを読み書きする方法です。
これは中身を読まずにメッセージを転送するプロキシーの様なアプリケーションで必要になります。

;When you work with multipart messages, each part is a zmq_msg item. E.g., if you are sending a message with five parts, you must construct, send, and destroy five zmq_msg items. You can do this in advance (and store the zmq_msg items in an array or other structure), or as you send them, one-by-one.

マルチパートメッセージを扱うには、zmq_msgオブジェクトをそれぞれ処理する必要があります。
例えば、5つのフレームを送信するには、5つのメッセージを生成し、それぞれのzmq_msgオブジェクトを開放する必要があります。
その時zmq_msgオブジェクトを配列で持つなどして、まとめて行っても構いませんし、一つずつ生成して送信しても構いません。

;Here is how we send the frames in a multipart message (we receive each frame into a message object):

以下は、マルチパートメッセージを送信する方法です。

~~~
zmq_msg_send (&message, socket, ZMQ_SNDMORE);
…
zmq_msg_send (&message, socket, ZMQ_SNDMORE);
…
zmq_msg_send (&message, socket, 0);
~~~

;Here is how we receive and process all the parts in a message, be it single part or multipart:

以下は、メッセージを受信し、各メッセージフレームを処理する方法です。

~~~
while (1) {
    zmq_msg_t message;
    zmq_msg_init (&message);
    zmq_msg_recv (&message, socket, 0);
    // Process the message frame
    …
    zmq_msg_close (&message);
    if (!zmq_msg_more (&message))
        break; // Last message frame
}
~~~

;Some things to know about multipart messages:

マルチパートについて以下の事を知っておいてください。

; * When you send a multipart message, the first part (and all following parts) are only actually sent on the wire when you send the final part.
; * If you are using zmq_poll(), when you receive the first part of a message, all the rest has also arrived.
; * You will receive all parts of a message, or none at all.
; * Each part of a message is a separate zmq_msg item.
; * You will receive all parts of a message whether or not you check the more property.
; * On sending, ØMQ queues message frames in memory until the last is received, then sends them all.
; * There is no way to cancel a partially sent message, except by closing the socket.

 * マルチパートを送信する際、最初のメッセージフレームは実際には最後のメッセージフレームを送信する時にまとめて送信されます。
 * `zmq_poll()`を利用している場合、最初のメッセージを受信した時には、もう残りのメッセージは全て到着しています。
 * マルチパートメッセージは全て受信するか、全く受信しないかのどちらかです。
 * メッセージフレームはzmq_msgオブジェクトで分割されます。
 * `zmq_msg_more`を呼び出してmore属性を確認してもしなくても、全てのメッセージを受信することになります。
 * 送信時、全てのメッセージフレームが送信され、最後のフレームが受信されるまで、メモリ上のØMQキューに保存されています。
 * 送信したメッセージフレームを部分的に取り消すには、ソケットをクローズするしか方法はありません。

### 中継とプロキシー
;ØMQ aims for decentralized intelligence, but that doesn't mean your network is empty space in the middle. It's filled with message-aware infrastructure and quite often, we build that infrastructure with ØMQ. The ØMQ plumbing can range from tiny pipes to full-blown service-oriented brokers. The messaging industry calls this intermediation, meaning that the stuff in the middle deals with either side. In ØMQ, we call these proxies, queues, forwarders, device, or brokers, depending on the context.

ØMQは知性の分散を目指しますが、ネットワークの中央に何もないというわけではありません。
そこにはメッセージを扱うインフラやØMQで構築したインフラで満たされています。
ØMQは小さなパイプから、完全なサービス指向ブローカーまで様々な配管を行うことが可能です。
メッセージング業界では、中央でメッセージを取り扱う役割を仲介者と呼びます。
ØMQではこの役割の事を文脈に依存してプロキシー、キュー、フォワーダー、デバイス、ブローカと呼びます。

;This pattern is extremely common in the real world and is why our societies and economies are filled with intermediaries who have no other real function than to reduce the complexity and scaling costs of larger networks. Real-world intermediaries are typically called wholesalers, distributors, managers, and so on.

私達の社会や経済の中で巨大なネットワークを持つ仲介者が溢れている様に、この様なパターンは現実の世界では極めて一般的です。
現実世界の言葉では、問屋、卸業者などと呼ばれます。

### 動的ディスカバリー問題
;One of the problems you will hit as you design larger distributed architectures is discovery. That is, how do pieces know about each other? It's especially difficult if pieces come and go, so we call this the "dynamic discovery problem".

ディスカバリーは大きなアーキテクチャを設計する上で遭遇する問題の一つです。
部品はどうやってその他の部品を見つければ良いのでしょうか。
部品が動的に増減する場合、これは特に難しいので、私達はこれを「動的ディスカバリー問題」と呼んでいます。

;There are several solutions to dynamic discovery. The simplest is to entirely avoid it by hard-coding (or configuring) the network architecture so discovery is done by hand. That is, when you add a new piece, you reconfigure the network to know about it.

動的ディスカバリー問題には幾つかの解決方法があります。
最もシンプルな方法は、接続先をハードコーディングもしくは設定で指定することです。
しかしこの方法では、新しい部品を追加した時にネットワークを再構成する必要があります。

![Small-Scale Pub-Sub Network](images/fig12.eps)

;In practice, this leads to increasingly fragile and unwieldy architectures. Let's say you have one publisher and a hundred subscribers. You connect each subscriber to the publisher by configuring a publisher endpoint in each subscriber. That's easy. Subscribers are dynamic; the publisher is static. Now say you add more publishers. Suddenly, it's not so easy any more. If you continue to connect each subscriber to each publisher, the cost of avoiding dynamic discovery gets higher and higher.

実際には、この方法は次第に脆く、扱いにくいアーキテクチャになるでしょう。
例えば、1つのパブリッシャーと100のサブスクライバー居るとしましょう。
各サブスクライバーがパブリッシャーに接続するために、各サブスクライバーにパブリッシャーのエンドポイントを設定する必要があります。
サブスクライバーは動的な部品であり、パブリッシャーは静的な部品なので、まあこれは簡単です。
しかし突然パブリッシャーを追加しなければならなくなった時、これは簡単な事ではありません。
サブスクライバーからパブリッシャーへの接続が増え続けていった場合、動的ディスカバリー問題を回避するコストは高まっていきます。

![Pub-Sub Network with a Proxy](images/fig13.eps)

;There are quite a few answers to this, but the very simplest answer is to add an intermediary; that is, a static point in the network to which all other nodes connect. In classic messaging, this is the job of the message broker. ØMQ doesn't come with a message broker as such, but it lets us build intermediaries quite easily.

これには幾つかの解決方法がありますが、単純な解決方法は、ネットワークの静的なポイントとなる仲介者を導入することです。
古典的なメッセージングシステムでは、この仕事はメッセージブローカーの役目とされていました。
ØMQではメッセージブローカーは存在しませんが、とても簡単に仲介者を構築することが出来ます。

;You might wonder, if all networks eventually get large enough to need intermediaries, why don't we simply have a message broker in place for all applications? For beginners, it's a fair compromise. Just always use a star topology, forget about performance, and things will usually work. However, message brokers are greedy things; in their role as central intermediaries, they become too complex, too stateful, and eventually a problem.

巨大なネットワークが最終的に仲介者を必要とするなら、なぜ単純にメッセージブローカーを導入しないのか不思議に思うかもしれません。
入門者の場合、それは適切な妥協策です。
パフォーマンスの事を無視すれば常にスター型トポロジが問題なく動作するでしょう。
しかしながらブローカは強欲であり、様々な役割を中央集権した結果、どんどんステートフルで複雑になり、最終的には問題が発生します。

;It's better to think of intermediaries as simple stateless message switches. A good analogy is an HTTP proxy; it's there, but doesn't have any special role. Adding a pub-sub proxy solves the dynamic discovery problem in our example. We set the proxy in the "middle" of the network. The proxy opens an XSUB socket, an XPUB socket, and binds each to well-known IP addresses and ports. Then, all other processes connect to the proxy, instead of to each other. It becomes trivial to add more subscribers or publishers.

仲介者はステートレスなメッセージスイッチとして考えた方が良いでしょう。
似たような例えとしてHTTPプロキシーがあります。これは特別な役割を持っていません。
以下のサンプルコードでは、pub-subプロキシーを追加することで動的ディスカバリー問題を解決します。
ネットワークの中間にプロキシーを配置し、そのプロキシーはXSUBソケットを開き、公開されたIPアドレスとポートでXPUBソケットを待ち受けます。
そして、全てのプロセスは、プロキシーに対して接続を行います。
これにより、サブスクライバーやパブリッシャーを追加することが容易になります。

![Extended Pub-Sub](images/fig14.eps)

;We need XPUB and XSUB sockets because ØMQ does subscription forwarding from subscribers to publishers. XSUB and XPUB are exactly like SUB and PUB except they expose subscriptions as special messages. The proxy has to forward these subscription messages from subscriber side to publisher side, by reading them from the XSUB socket and writing them to the XPUB socket. This is the main use case for XSUB and XPUB.

接続をサブスクライバーからパブリッシャーに転送するためにはXPUBソケットとXSUBソケットが必要です。
XSUBとXPUBは特別に生のメッセージを転送するという点を除いて、SUB, PUBソケットとまったく同じです。
プロキシーはXSUB, XPUBソケットを読み書きする事でサブスクライバー側からのメッセージをパブリッシャー側に転送します。
これはXSUB, XPUBソケットの主要な利用方法です。

### 共有キュー(DEALER and ROUTER sockets)
;In the Hello World client/server application, we have one client that talks to one service. However, in real cases we usually need to allow multiple services as well as multiple clients. This lets us scale up the power of the service (many threads or processes or nodes rather than just one). The only constraint is that services must be stateless, all state being in the request or in some shared storage such as a database.

Hello Worldクライアント・サーバーアプリケーションの例では、1つのクライアントが1つのサービスに接続を行いました。
実際のケースでは、複数のクライアントが複数のサービスに接続できる必要があります。
これは、スレッド、プロセス、ノードを増やすことでスケールアップしてサービスを拡張することが出来ます。
唯一の制限は、サービスはステートレスでなければなりません。全ての状態はデーターベースなどのストレージに格納されている必要があります。

![Request Distribution](images/fig15.eps)

;There are two ways to connect multiple clients to multiple servers. The brute force way is to connect each client socket to multiple service endpoints. One client socket can connect to multiple service sockets, and the REQ socket will then distribute requests among these services. Let's say you connect a client socket to three service endpoints; A, B, and C. The client makes requests R1, R2, R3, R4. R1 and R4 go to service A, R2 goes to B, and R3 goes to service C.

複数のクライアントから複数のサーバーに接続する方法は2つあります。
強引な方法だと複数のサービスに対してそれぞれのソケットを用意して接続し、分散したリクエストを行います。
上記の図は、サービスのエンドポイントA, B, Cに対して、クライアントはR1, R2, R3, R4という4つのリクエストを行っています。
そして、R1とR4はサービスAに、R2はサービスBに、R3はサービスCにリクエストが行われていることを示しています。

;This design lets you add more clients cheaply. You can also add more services. Each client will distribute its requests to the services. But each client has to know the service topology. If you have 100 clients and then you decide to add three more services, you need to reconfigure and restart 100 clients in order for the clients to know about the three new services.

この設計でクライアントとサービスを追加するのは比較的簡単でしょう。
各クライアントはサービスに対して分散してリクエストを送ります。
しかし各クライアントはサービスのトポロジーを把握している必要があります。
もし、100のクライアント居て、新しいサービスを追加する場合、100のクライアントにに対して再設定と再起動を行う必要があります。

;That's clearly not the kind of thing we want to be doing at 3 a.m. when our supercomputing cluster has run out of resources and we desperately need to add a couple of hundred of new service nodes. Too many static pieces are like liquid concrete: knowledge is distributed and the more static pieces you have, the more effort it is to change the topology. What we want is something sitting in between clients and services that centralizes all knowledge of the topology. Ideally, we should be able to add and remove services or clients at any time without touching any other part of the topology.

突然スパコンのクラスタのリソース不足が発生し、数百のサービスノードを追加する必要が発生したとして、この様な作業を夜中の3時にやりたいとは思いません。
多くの静的な部品は液体コンクリートの様な物です。知識が多くの静的部品に分散していると、トポロジーの変更が大変です。
私達に必要なのは、クライアントとサービスの間に居て、トポロジーに関する全ての知識を持った存在です。
これがあれば、トポロジーの他の部品に触れることなく、いつでもサービスやクライアントを追加したり削除したりできるはずです。

;So we'll write a little message queuing broker that gives us this flexibility. The broker binds to two endpoints, a frontend for clients and a backend for services. It then uses zmq_poll() to monitor these two sockets for activity and when it has some, it shuttles messages between its two sockets. It doesn't actually manage any queues explicitly—ØMQ does that automatically on each socket.

ですのでこの様な柔軟性を提供するちょっとしたメッセージキューブローカーを書いてみます。
ブローカーはクライアント側のフロントエンドとサービス側のバックエンドの2つのエンドポイントをbindします。
そしてzmq_poll()を利用して2つのソケットの動作を監視して、メッセージを橋渡しします。
ØMQが自動的にキューを管理していますので、ブローカが直接それを行うことはありません。

;When you use REQ to talk to REP, you get a strictly synchronous request-reply dialog. The client sends a request. The service reads the request and sends a reply. The client then reads the reply. If either the client or the service try to do anything else (e.g., sending two requests in a row without waiting for a response), they will get an error.

REQソケットからREPソケットに通信する際、厳密には同期的にやりとりを行います。
サービスはリクエストを受信し、応答を返します。その後、クライアントは応答を受信します。
もし、クライアントやサービスがこれ以外の動作(例えば応答を待ってる時に2つ目のリクエストを送信するなど)を行うとエラーが返ります。

;But our broker has to be nonblocking. Obviously, we can use zmq_poll() to wait for activity on either socket, but we can't use REP and REQ.

しかし今回のブローカーは非同期で行います。REP/REQソケットを利用せず、zmq_poll()を利用してソケットを監視します。

![Extended Request-Reply](images/fig16.eps)

;Luckily, there are two sockets called DEALER and ROUTER that let you do nonblocking request-response. You'll see in Chapter 3 - Advanced Request-Reply Patterns how DEALER and ROUTER sockets let you build all kinds of asynchronous request-reply flows. For now, we're just going to see how DEALER and ROUTER let us extend REQ-REP across an intermediary, that is, our little broker.

幸いなことに、リクエスト・応答を非ブロッキングで行うDEALERとROUTERと呼ばれる2つのソケットがあります。
第3章「リクエスト・応答パターンの応用」ではDEALERとROUTERソケットを利用した様々な非同期のリクエスト・応答パターンを見ていきます。
ここでは、リクエスト・応答パターンの仲介者として動作する簡単なブローカーを実装する方法としてDEALERとROUTERの説明を行います。

;In this simple extended request-reply pattern, REQ talks to ROUTER and DEALER talks to REP. In between the DEALER and ROUTER, we have to have code (like our broker) that pulls messages off the one socket and shoves them onto the other.

今回の単純なリクエスト・応答パターンでは、REQソケットはROUTERソケットと通信し、DEALERソケットはREPソケットと通信を行います。
DEALERとROUTERソケットの間では、ソケットに届いたメッセージを、もう一方に転送するブローカーの様なコードが動作しています。

;The request-reply broker binds to two endpoints, one for clients to connect to (the frontend socket) and one for workers to connect to (the backend). To test this broker, you will want to change your workers so they connect to the backend socket. Here is a client that shows what I mean:

リクエスト・応答ブローカーは2つのエンドポイントをbindします。
1つ目はクライアントが接続してくるフロントエンド側のソケットです。
もうひとつはワーカーが接続してくるバックエンド側のソケットです。
ブローカーの動作を確認するために、バックエンドのワーカーの数を変更してみたくなるでしょう。
以下はリクエストを行うクライアントのコードです。

~~~ {caption="rrclient: リクエスト・応答クライアント(C言語)"}
// Hello Worldクライアント
// Connects REQ socket to tcp://localhost:5559
// Sends "Hello" to server, expects "World" back

#include "zhelpers.h"

int main (void)
{
    void *context = zmq_ctx_new ();

    // Socket to talk to server
    void *requester = zmq_socket (context, ZMQ_REQ);
    zmq_connect (requester, "tcp://localhost:5559");

    int request_nbr;
    for (request_nbr = 0; request_nbr != 10; request_nbr++) {
        s_send (requester, "Hello");
        char *string = s_recv (requester);
        printf ("Received reply %d [%s]\n", request_nbr, string);
        free (string);
    }
    zmq_close (requester);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

以下はワーカーのコードです。

~~~ {caption="rrworker: リクエスト・応答ワーカー(C言語)"}
// Hello Worldワーカー
// Connects REP socket to tcp://*:5560
// Expects "Hello" from client, replies with "World"

#include "zhelpers.h"

int main (void)
{
    void *context = zmq_ctx_new ();

    // Socket to talk to clients
    void *responder = zmq_socket (context, ZMQ_REP);
    zmq_connect (responder, "tcp://localhost:5560");

    while (1) {
        // Wait for next request from client
        char *string = s_recv (responder);
        printf ("Received request: [%s]\n", string);
        free (string);

        // Do some 'work'
        sleep (1);

        // Send reply back to client
        s_send (responder, "World");
    }
    // We never get here, but clean up anyhow
    zmq_close (responder);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

そして以下がブローカーのコードです。マルチパートメッセージも正しく処理できます。

~~~ {caption="rrbroker: リクエスト・応答ブローカー(C言語)"}
// Simple request-reply broker

#include "zhelpers.h"

int main (void)
{
    // Prepare our context and sockets
    void *context = zmq_ctx_new ();
    void *frontend = zmq_socket (context, ZMQ_ROUTER);
    void *backend = zmq_socket (context, ZMQ_DEALER);
    zmq_bind (frontend, "tcp://*:5559");
    zmq_bind (backend, "tcp://*:5560");

    // Initialize poll set
    zmq_pollitem_t items [] = {
        { frontend, 0, ZMQ_POLLIN, 0 },
        { backend, 0, ZMQ_POLLIN, 0 }
    };
    // Switch messages between sockets
    while (1) {
        zmq_msg_t message;
        zmq_poll (items, 2, -1);
        if (items [0].revents & ZMQ_POLLIN) {
            while (1) {
                // Process all parts of the message
                zmq_msg_init (&message);
                zmq_msg_recv (&message, frontend, 0);
                int more = zmq_msg_more (&message);
                zmq_msg_send (&message, backend, more? ZMQ_SNDMORE: 0);
                zmq_msg_close (&message);
                if (!more)
                    break; // Last message part
            }
        }
        if (items [1].revents & ZMQ_POLLIN) {
            while (1) {
                // Process all parts of the message
                zmq_msg_init (&message);
                zmq_msg_recv (&message, backend, 0);
                int more = zmq_msg_more (&message);
                zmq_msg_send (&message, frontend, more? ZMQ_SNDMORE: 0);
                zmq_msg_close (&message);
                if (!more)
                    break; // Last message part
            }
        }
    }
    // We never get here, but clean up anyhow
    zmq_close (frontend);
    zmq_close (backend);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

![Request-Reply Broker](images/fig17.eps)

;Using a request-reply broker makes your client/server architectures easier to scale because clients don't see workers, and workers don't see clients. The only static node is the broker in the middle.

リクエスト・応答ブローカーを利用すると、クライアントは直接ワーカーの数を気にしなくて良くなるのでアーキテクチャを拡張し易くなります。
これにより、静的なノードは中間にあるブローカのみとなります。

### ØMQの組み込みプロキシー関数
;It turns out that the core loop in the previous section's rrbroker is very useful, and reusable. It lets us build pub-sub forwarders and shared queues and other little intermediaries with very little effort. ØMQ wraps this up in a single method, zmq_proxy():

前節のrrbrokerは非常に便利でメインループに注目すると再利用可能である事が分ります。
キューを共有してpub-sub転送行う仲介者もわずかな手間で実装出来ます。
ØMQはこの様な機能をラップした単一の関数`zmq_proxy()`を用意しています。

~~~
zmq_proxy (frontend, backend, capture);
~~~

;The two (or three sockets, if we want to capture data) must be properly connected, bound, and configured. When we call the zmq_proxy method, it's exactly like starting the main loop of rrbroker. Let's rewrite the request-reply broker to call zmq_proxy, and re-badge this as an expensive-sounding "message queue" (people have charged houses for code that did less):

この関数は3つの引数をとります(3つ目の引き数はデータの採取が必要であれば)。
`zmq_proxy()`関数を呼び出すと、まさにrrbrokerのメインループを実行します。
それではzmq_proxyを利用して、リクエスト・応答ブローカーを書きなおしてみましょう。
[TODO]

~~~ {caption="msgqueue: Message queue broker in C"}
// Simple message queuing broker
// Same as request-reply broker but using QUEUE device

#include "zhelpers.h"

int main (void)
{
    void *context = zmq_ctx_new ();

    // Socket facing clients
    void *frontend = zmq_socket (context, ZMQ_ROUTER);
    int rc = zmq_bind (frontend, "tcp://*:5559");
    assert (rc == 0);

    // Socket facing services
    void *backend = zmq_socket (context, ZMQ_DEALER);
    rc = zmq_bind (backend, "tcp://*:5560");
    assert (rc == 0);

    // Start the proxy
    zmq_proxy (frontend, backend, NULL);

    // We never get here…
    zmq_close (frontend);
    zmq_close (backend);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

;If you're like most ØMQ users, at this stage your mind is starting to think, "What kind of evil stuff can I do if I plug random socket types into the proxy?" The short answer is: try it and work out what is happening. In practice, you would usually stick to ROUTER/DEALER, XSUB/XPUB, or PULL/PUSH.

あなたが典型的なØMQユーザーであれば、この段階でこう考えるでしょう。
「プロキシーのソケット種別に何を指定しても良いのかな?」
簡単な答えると、「通常はROUTER/DEALER, XSUB/XPUB, PULL/PUSH の組み合わせしか利用しません。」

### ブリッジ通信
;A frequent request from ØMQ users is, "How do I connect my ØMQ network with technology X?" where X is some other networking or messaging technology.

ØMQユーザーからのよくある質問に、「どの様にしてØMQネットワークと通信技術Xと接続すれば良いですか?」というものがあります。
Xはその他の通信技術やメッセージングプラットフォームの事です。

![Pub-Sub Forwarder Proxy](images/fig18.eps)

;The simple answer is to build a bridge. A bridge is a small application that speaks one protocol at one socket, and converts to/from a second protocol at another socket. A protocol interpreter, if you like. A common bridging problem in ØMQ is to bridge two transports or networks.

単純な解決方法はブリッジを構築することです。ブリッジとは片方で1つのプロトコルに対応するソケットを持ち、もう片方で別のプロトコルに変換して接続を行う小さなアプリケーションです。
これはプロトコルインタプリターと言っても構いません。
[TODO]これは2つの異なる通信方式やネットワークをブリッジする際に役立ちます。

;As an example, we're going to write a little proxy that sits in between a publisher and a set of subscribers, bridging two networks. The frontend socket (SUB) faces the internal network where the weather server is sitting, and the backend (PUB) faces subscribers on the external network. It subscribes to the weather service on the frontend socket, and republishes its data on the backend socket.

例として、パブリッシャーとサブスクライバーの間の2つのネットワークをブリッジする小さなプロキシーを作ってみましょう。
フロントエンドソケット(SUB)は気象情報サーバーが居る内部ネットワークに面しており、バックエンドソケット(PUB)は外部ネットワークに面しています。
このプロキシーはフロントエンドソケットで気象情報の更新を受信し、バックエンドソケットにデータを再配布します。

~~~ {caption="wuproxy: Weather update proxy in C"}
// Weather proxy device

#include "zhelpers.h"

int main (void)
{
    void *context = zmq_ctx_new ();

    // This is where the weather server sits
    void *frontend = zmq_socket (context, ZMQ_XSUB);
    zmq_connect (frontend, "tcp://192.168.55.210:5556");

    // This is our public endpoint for subscribers
    void *backend = zmq_socket (context, ZMQ_XPUB);
    zmq_bind (backend, "tcp://10.1.1.0:8100");

    // Run the proxy until the user interrupts us
    zmq_proxy (frontend, backend, NULL);

    zmq_close (frontend);
    zmq_close (backend);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

;It looks very similar to the earlier proxy example, but the key part is that the frontend and backend sockets are on two different networks. We can use this model for example to connect a multicast network (pgm transport) to a tcp publisher.

これはプロキシーの時に見たサンプルコードとよく似ていますが、フロントエンドソケットとバックエンドソケットが異なるネットワークにある所がポイントです。
この方法は、TCPのサブスクライバから受け取ったメッセージをマルチキャストネットワークに流すような場合にも利用できます。

## エラー処理とETERM
;ØMQ's error handling philosophy is a mix of fail-fast and resilience. Processes, we believe, should be as vulnerable as possible to internal errors, and as robust as possible against external attacks and errors. To give an analogy, a living cell will self-destruct if it detects a single internal error, yet it will resist attack from the outside by all means possible.

ØMQにおけるエラーハンドリングの哲学はフェイル・ファーストと回復力の組み合わせです。
[TODO]
システムは内部エラーに関しては出来るだけ脆弱であるべきであり、外部要因のエラーや攻撃に対しては出来るだけ強固であるべきです。
例えば生体細胞は、単一の内部エラーが発生すると自己崩壊するように出来ていますが、外部からの攻撃に対しては出来るだけ対抗しようとします。

;Assertions, which pepper the ØMQ code, are absolutely vital to robust code; they just have to be on the right side of the cellular wall. And there should be such a wall. If it is unclear whether a fault is internal or external, that is a design flaw to be fixed. In C/C++, assertions stop the application immediately with an error. In other languages, you may get exceptions or halts.

[TODO]アサーションはØMQコードを強固にする為に欠かせない調味料です。
これには細胞壁のような壁があるはずです。
もし障害が内部要因か外部要因かの区別がつかない場合、それは設計上の欠陥です。
C/C++ではアサーションはアプリケーションを直ちに停止させます。
他の言語では例外を投げるか、あるいは終了するでしょう。

;When ØMQ detects an external fault it returns an error to the calling code. In some rare cases, it drops messages silently if there is no obvious strategy for recovering from the error.

ØMQが外部要因の障害を検出するとエラーをコードに返します。
エラーからの復旧戦略がない場合、稀にメッセージを喪失してしまう可能性があります。

;In most of the C examples we've seen so far there's been no error handling. Real code should do error handling on every single ØMQ call. If you're using a language binding other than C, the binding may handle errors for you. In C, you do need to do this yourself. There are some simple rules, starting with POSIX conventions:

これまで見てきたC言語のサンプルコードではエラー処理を行っていませんでした。
実際のコードでは、ØMQ APIの呼び出し毎にエラー処理を行う必要があります。
もしあなたがC言語でなくその他の言語のバインディングを利用している場合はバインディングがエラー処理を行ってくれるでしょう。
C言語ではそれを自分でやる必要があります。
そのルールはPOSIXの決まりごと似たような感じで単純です。

;* Methods that create objects return NULL if they fail.
;* Methods that process data may return the number of bytes processed, or -1 on an error or failure.
;* Other methods return 0 on success and -1 on an error or failure.
;* The error code is provided in errno or zmq_errno().
;* A descriptive error text for logging is provided by zmq_strerror().

;* オブジェクトの生成に失敗した場合はNULLを返します。
;* データを処理する関数は処理したデータのバイト数を返すか、失敗した場合に-1を返します。
;* その他の関数は成功した場合に0、失敗した場合に-1を返します。
;* エラーコードは`errno`や`zmq_errno()`で取得できます。
;* エラーの説明文字は`zmq_strerror()`で取得できます。

例:

~~~
void *context = zmq_ctx_new ();
assert (context);
void *socket = zmq_socket (context, ZMQ_REP);
assert (socket);
int rc = zmq_bind (socket, "tcp://*:5555");
if (rc == -1) {
    printf ("E: bind failed: %s\n", strerror (errno));
    return -1;
}
~~~

;There are two main exceptional conditions that you should handle as nonfatal:

致命的なエラーとして扱ってはいけない例外的な状況が主に2つあります。

;* When your code receives a message with the ZMQ_DONTWAIT option and there is no waiting data, ØMQ will return -1 and set errno to EAGAIN.

;* When one thread calls zmq_ctx_destroy(), and other threads are still doing blocking work, the zmq_ctx_destroy() call closes the context and all blocking calls exit with -1, and errno set to ETERM.

* `ZMQ_DONTWAIT`を指定してメッセージを受信しようとして実際に受信するデータが無かった場合、ØMQは-1を返してerrnoにEAGAINをセットします。

* あるスレッドが`zmq_ctx_destroy()`を呼び出した際に、まだ別のスレッドがブロッキング処理中であった場合。`zmq_ctx_destroy()`はコンテキストを正しく開放し、ブロッキング処理を行っている関数は-1を返してerrnoに`ETERM`をセットします。

;In C/C++, asserts can be removed entirely in optimized code, so don't make the mistake of wrapping the whole ØMQ call in an assert(). It looks neat; then the optimizer removes all the asserts and the calls you want to make, and your application breaks in impressive ways.

C/C++の`assert()`は最適化によって完全に取り除く事ができるので全てのØMQ内で呼び出される`assert()`をラップする必要はありません。
[TODO]最適化に依って全ての`assert()`を削除し、見事な方法でアプリケーションを終了させます。

![Parallel Pipeline with Kill Signaling](images/fig19.eps)

;Let's see how to shut down a process cleanly. We'll take the parallel pipeline example from the previous section. If we've started a whole lot of workers in the background, we now want to kill them when the batch is finished. Let's do this by sending a kill message to the workers. The best place to do this is the sink because it really knows when the batch is done.

プロセスを行儀よく終了させる方法を見て行きましょう。
以前の節で出てきた、並行パイプラインのサンプルコードを思い出しましょう。
無事に処理が完了し、バックグラウンドで動作している大量のワーカーを終了させたいとします。
こんな時はワーカーに対して終了メッセージを送信してみましょう。
この処理行うのに最適な部品はシンクです。なぜならシンクは処理の完了を知ることができるからです。

;How do we connect the sink to the workers? The PUSH/PULL sockets are one-way only. We could switch to another socket type, or we could mix multiple socket flows. Let's try the latter: using a pub-sub model to send kill messages to the workers:

どの様にしてシンクからワーカーに接続すればよいでしょうか。
PUSH/PULLソケットは一方方向ですし、動作中の別のソケット種別に切り替えたりすることは出来ません。
ではpub-subモデルでワーカーに終了メッセージを送る方法について説明しましょう。

;* The sink creates a PUB socket on a new endpoint.
;* Workers bind their input socket to this endpoint.
;* When the sink detects the end of the batch, it sends a kill to its PUB socket.
;* When a worker detects this kill message, it exits.

* シンクで新しいPUBソケットのエンドポイントを作成します。
* ワーカーで新しいエンドポイントを作成します。
* シンクで処理の完了を確認したら、PUBソケットに対してKILLメッセージを送信します。
* ワーカーはKILLメッセージを受信し、終了します。

It doesn't take much new code in the sink:
追加のコードはそれほど必要ありません。

~~~
void *controller = zmq_socket (context, ZMQ_PUB);
zmq_bind (controller, "tcp://*:5559");
…
// Send kill signal to workers
s_send (controller, "KILL");
~~~

;Here is the worker process, which manages two sockets (a PULL socket getting tasks, and a SUB socket getting control commands), using the zmq_poll() technique we saw earlier:

この場合ワーカープロセスは2つのソケットを先ほど学んだ`zmq_poll()`を使って管理します。
1つ目はタスクを受信を行うソケット、もうひとつはKILLメッセージなどの制御コマンドを受信するソケットです。

~~~ {caption="taskwork2: Parallel task worker with kill signaling in C"}
// Task worker - design 2
// Adds pub-sub flow to receive and respond to kill signal

#include "zhelpers.h"

int main (void)
{
    // Socket to receive messages on
    void *context = zmq_ctx_new ();
    void *receiver = zmq_socket (context, ZMQ_PULL);
    zmq_connect (receiver, "tcp://localhost:5557");

    // Socket to send messages to
    void *sender = zmq_socket (context, ZMQ_PUSH);
    zmq_connect (sender, "tcp://localhost:5558");

    // Socket for control input
    void *controller = zmq_socket (context, ZMQ_SUB);
    zmq_connect (controller, "tcp://localhost:5559");
    zmq_setsockopt (controller, ZMQ_SUBSCRIBE, "", 0);

    // Process messages from either socket
    while (1) {
        zmq_pollitem_t items [] = {
            { receiver, 0, ZMQ_POLLIN, 0 },
            { controller, 0, ZMQ_POLLIN, 0 }
        };
        zmq_poll (items, 2, -1);
        if (items [0].revents & ZMQ_POLLIN) {
            char *string = s_recv (receiver);
            printf ("%s.", string); // Show progress
            fflush (stdout);
            s_sleep (atoi (string)); // Do the work
            free (string);
            s_send (sender, ""); // Send results to sink
        }
        // Any waiting controller command acts as 'KILL'
        if (items [1].revents & ZMQ_POLLIN)
            break; // Exit loop
    }
    zmq_close (receiver);
    zmq_close (sender);
    zmq_close (controller);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

;Here is the modified sink application. When it's finished collecting results, it broadcasts a kill message to all workers:

こちらは、改修を行ったシンクアプリケーションです。
結果の収集が完了した時に終了メッセージを全てのワーカーにブロードキャストしています。

~~~ {caption="tasksink2: Parallel task sink with kill signaling in C"}
// Task sink - design 2
// Adds pub-sub flow to send kill signal to workers

#include "zhelpers.h"

int main (void)
{
    // Socket to receive messages on
    void *context = zmq_ctx_new ();
    void *receiver = zmq_socket (context, ZMQ_PULL);
    zmq_bind (receiver, "tcp://*:5558");

    // Socket for worker control
    void *controller = zmq_socket (context, ZMQ_PUB);
    zmq_bind (controller, "tcp://*:5559");

    // Wait for start of batch
    char *string = s_recv (receiver);
    free (string);

    // Start our clock now
    int64_t start_time = s_clock ();

    // Process 100 confirmations
    int task_nbr;
    for (task_nbr = 0; task_nbr < 100; task_nbr++) {
        char *string = s_recv (receiver);
        free (string);
        if ((task_nbr / 10) * 10 == task_nbr)
        printf (":");
    else
        printf (".");
        fflush (stdout);
    }
    printf ("Total elapsed time: %d msec\n",
    (int) (s_clock () - start_time));

    // Send kill signal to workers
    s_send (controller, "KILL");

    zmq_close (receiver);
    zmq_close (controller);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

## 割り込みシグナル処理
;Realistic applications need to shut down cleanly when interrupted with Ctrl-C or another signal such as SIGTERM. By default, these simply kill the process, meaning messages won't be flushed, files won't be closed cleanly, and so on.

実際のアプリケーションではCtrl-Cやその他のシグナルを受け取って行儀よく終了する必要があります。
既定では、killシグナルを受信すると即座に終了するので、メッセージはキューを溜めたままになり、ファイルなどもクローズされません。

;Here is how we handle a signal in various languages:

以下はシグナルを処理する方法です。

~~~ {caption="interrupt: Handling Ctrl-C cleanly in C"}
while (true) {
    zstr_send (client, "Hello");
    char *reply = zstr_recv (client);
    if (!reply)
        break; // 割り込み発生
    printf ("Client: %s\n", reply);
    free (reply);
    sleep (1);
}
~~~

;The program provides s_catch_signals(), which traps Ctrl-C (SIGINT) and SIGTERM. When either of these signals arrive, the s_catch_signals() handler sets the global variable s_interrupted. Thanks to your signal handler, your application will not die automatically. Instead, you have a chance to clean up and exit gracefully. You have to now explicitly check for an interrupt and handle it properly. Do this by calling s_catch_signals() (copy this from interrupt.c) at the start of your main code. This sets up the signal handling. The interrupt will affect ØMQ calls as follows:

次のプログラムは`s_catch_signals()`を呼び出してCtrl-C(SIGINT)やSIGTERMをトラップします。
これらのシグナルを受信すると`s_catch_signals()`によってグローバル変数`s_interrupted`を設定します。
この場合、アプリケーションは自動的に終了しません。シグナルハンドラに感謝して下さい。
代わりにリソースを開放して行儀よく終了する事が出来ます。
これは明示的に割り込みを確認して正しく処理する必要があります。
メインコードの最初でこの`s_catch_signals()`を呼び出して下さい。
割り込みは以下のØMQ APIの呼び出しに影響します。

;* If your code is blocking in a blocking call (sending a message, receiving a message, or polling), then when a signal arrives, the call will return with EINTR.
;* Wrappers like s_recv() return NULL if they are interrupted.

* 同期的なメッセージの送受信でブロッキングしている最中にシグナルを受信すると、その関数は`EINTR`を返します。
* `s_recv()`の様なラッパー関数は割り込みが入るとNULLを返します。

;So check for an EINTR return code, a NULL return, and/or s_interrupted.

ですので関数の返り値がEINTRやNULLになっていないか確認し、必要に応じてグローバル変数`s_interrupted`も確認して下さい。

;Here is a typical code fragment:

以下は典型的なコード片です。

~~~
s_catch_signals ();
client = zmq_socket (...);
while (!s_interrupted) {
    char *message = s_recv (client);
    if (!message)
        break;          //  Ctrl-C が押された
}
zmq_close (client);
~~~

;If you call s_catch_signals() and don't test for interrupts, then your application will become immune to Ctrl-C and SIGTERM, which may be useful, but is usually not.

もしも`s_catch_signals()`を呼び出しておいて、`s_interrupted`をチェックしなかった場合、Ctrl-CやSIGTERMは無視されるようになります。これは便利かもしれませんが一般的ではありません。

## メモリリークの検出
;Any long-running application has to manage memory correctly, or eventually it'll use up all available memory and crash. If you use a language that handles this automatically for you, congratulations. If you program in C or C++ or any other language where you're responsible for memory management, here's a short tutorial on using valgrind, which among other things will report on any leaks your programs have.

長期間動作し続けるアプリケーションは適切にメモリを管理してやる必要があります、そうしなければ全てのメモリを使い果たして最後にはクラッシュしてしまうからです。
自動的にメモリ管理を行う言語を利用しているそこのあなた、おめでとうございます。
C言語やC++でプログラムを書く場合はメモリ管理の責任はプログラマにあります。
以下は、valgrindを利用してプログラムのメモリリークを調査する為の簡単なチュートリアルです。

;* To install valgrind, e.g., on Ubuntu or Debian, issue this command:

* valgrindをインストールするには、UbuntuやDebianでは以下のコマンドを実行します。

~~~
sudo apt-get install valgrind
~~~

;* By default, ØMQ will cause valgrind to complain a lot. To remove these warnings, create a file called vg.supp that contains this:

* valgrindは既定では多くの警告を表示します。問題の無い警告を無視するために以下の内容のファイル(vg.supp)を作成して下さい。

~~~
{
   <socketcall_sendto>
   Memcheck:Param
   socketcall.sendto(msg)
   fun:send
   ...
}
{
    <socketcall_sendto>
    Memcheck:Param
    socketcall.send(msg)
    fun:send
    ...
}
~~~

;* Fix your applications to exit cleanly after Ctrl-C. For any application that exits by itself, that's not needed, but for long-running applications, this is essential, otherwise valgrind will complain about all currently allocated memory.

* Ctrl-Cを押した時に行儀よくアプリケーションを終了するようにしてください。勝手に終了する場合これは必要無いですが、長期間動作し続けるアプリケーションでは必要不可欠です。行儀よく終了しなかった場合はvalgrindが開放していないメモリ領域に関して警告を表示します。

;* Build your application with -DDEBUG if it's not your default setting. That ensures valgrind can tell you exactly where memory is being leaked.

* コンパイルオプションに`-DDEBUG`を付けてアプリケーションをビルドすると、valgrindはメモリリークに関する警告をより詳細に教えてくれます。

;* Finally, run valgrind thus:

* valgrindは以下のように実行して下さい。

~~~
valgrind --tool=memcheck --leak-check=full --suppressions=vg.supp someprog
~~~

;And after fixing any errors it reported, you should get the pleasant message:

そして、何も問題が見つからなかれば、以下のように素敵なメッセージが表示されます。

~~~
==30536== ERROR SUMMARY: 0 errors from 0 contexts...
~~~

## マルチスレッドとØMQ
;ØMQ is perhaps the nicest way ever to write multithreaded (MT) applications. Whereas ØMQ sockets require some readjustment if you are used to traditional sockets, ØMQ multithreading will take everything you know about writing MT applications, throw it into a heap in the garden, pour gasoline over it, and set it alight. It's a rare book that deserves burning, but most books on concurrent programming do.[TODO]

恐らくØMQはマルチスレッドアプリケーションを書く為の最適な方法です。
古典的なソケットを利用する場合と比べてØMQソケットを使う場合はちょっとした調整を行えば良いだけで、あなたが知っているマルチスレッドプログラミングに関する知識をほとんど必要としません。
既存の知識は庭に放り投げて、油を注いで燃やして下さい。

;To make utterly perfect MT programs (and I mean that literally), we don't need mutexes, locks, or any other form of inter-thread communication except messages sent across ØMQ sockets.

ØMQの場合、完璧なマルチスレッドプログラムを作る為に*mutexやロック、プロセス間通信などは必要ありません。*
***ØMQソケットを通じてメッセージを送信することだけを考えれば良いのです。***

;By "perfect MT programs", I mean code that's easy to write and understand, that works with the same design approach in any programming language, and on any operating system, and that scales across any number of CPUs with zero wait states and no point of diminishing returns.

私の言う「完璧なマルチスレッドプログラム」とは、書き易く理解しやすいコードであり、どの様なプログラミング言語やOSでも同じ設計方法で機能し、CPU数に比例して性能が向上してCPUリソースを無駄にすることが無いという意味を含んでいます。

;If you've spent years learning tricks to make your MT code work at all, let alone rapidly, with locks and semaphores and critical sections, you will be disgusted when you realize it was all for nothing. If there's one lesson we've learned from 30+ years of concurrent programming, it is: just don't share state. It's like two drunkards trying to share a beer. It doesn't matter if they're good buddies. Sooner or later, they're going to get into a fight. And the more drunkards you add to the table, the more they fight each other over the beer. The tragic majority of MT applications look like drunken bar fights.

もしあなたがロックやセマフォやクリティカルセクションなどのマルチスレッドプログラミングに関するテクニックを長年に渡って学んで来たのであれば、これらが如何に無駄な事だったかを思い知ることになるでしょう。
私達が30年以上の並行プログラミングの経験から学んだたった一つのことは「状態を共有してはいけない」という事です。
それは2人の酔っぱらいがビールを取り合っているようなものです。
彼らが仲の良い友達同士であれば問題にはなりませんが、そうで無ければ遅かれ早かれ喧嘩になってしまうことでしょう。
そして、そこに新しく酔っぱらいを追加するとかられもまたビールを巡って争いを初めます。
マルチスレッドアプリケーション大多数は酔っぱらいが居る酒場の喧嘩のようなものです。

;The list of weird problems that you need to fight as you write classic shared-state MT code would be hilarious if it didn't translate directly into stress and risk, as code that seems to work suddenly fails under pressure. A large firm with world-beating experience in buggy code released its list of "11 Likely Problems In Your Multithreaded Code", which covers forgotten synchronization, incorrect granularity, read and write tearing, lock-free reordering, lock convoys, two-step dance, and priority inversion.

以下のリストは、古典的な共有メモリのマルチスレッドアプリケーションで発生る問題の数々です。
これらの問題で発生するストレスとリスクに押しつぶされてしまったコードは突然動かなくなります。
バグのあるプログラムに関する経験では世界一の大企業が「マルチスレッドプログラムでよく見られる11の問題」という文書を公開しました。
この中では、同期忘れ、不適切な粒度、読み取りと書き込みの分裂、ロックフリーの並べ替え、ロックコンボイ、2ステップダンス、優先順位の逆転といった問題が挙げられています。

;Yeah, we counted seven problems, not eleven. That's not the point though. The point is, do you really want that code running the power grid or stock market to start getting two-step lock convoys at 3 p.m. on a busy Thursday? Who cares what the terms actually mean? This is not what turned us on to programming, fighting ever more complex side effects with ever more complex hacks.

はい、私は今11ではなく7つしか挙げませんでした。
これはさして問題ではありません。
重要なのは電力網や株式市場のシステムで忙しい木曜日の午後3時に2ステップロックコンボイをやりたいのか、という事です。
これはより複雑なハックで複雑な副作用と戦っているような物です。

;Some widely used models, despite being the basis for entire industries, are fundamentally broken, and shared state concurrency is one of them. Code that wants to scale without limit does it like the Internet does, by sending messages and sharing nothing except a common contempt for broken programming models.

広く使われているモデルは業界の基盤となっているにも関わらず、状態を共有するという根本的な欠陥があります。
インターネット上のサービスの様に無制限に拡張させたい場合、欠陥のあるプログラミングモデルのよう共有するのではなく、メッセージの送信を行いましょう。

;You should follow some rules to write happy multithreaded code with ØMQ:

ØMQで適切なマルチスレッドプログラムを書くには以下のルールに従う必要があります。

;* Isolate data privately within its thread and never share data in multiple threads. The only exception to this are ØMQ contexts, which are threadsafe.
;* Stay away from the classic concurrency mechanisms like as mutexes, critical sections, semaphores, etc. These are an anti-pattern in ØMQ applications.
;* Create one ØMQ context at the start of your process, and pass that to all threads that you want to connect via inproc sockets.
;* Use attached threads to create structure within your application, and connect these to their parent threads using PAIR sockets over inproc. The pattern is: bind parent socket, then create child thread which connects its socket.
;* Use detached threads to simulate independent tasks, with their own contexts. Connect these over tcp. Later you can move these to stand-alone processes without changing the code significantly.
;* All interaction between threads happens as ØMQ messages, which you can define more or less formally.
;* Don't share ØMQ sockets between threads. ØMQ sockets are not threadsafe. Technically it's possible to migrate a socket from one thread to another but it demands skill. The only place where it's remotely sane to share sockets between threads are in language bindings that need to do magic like garbage collection on sockets.

* データはスレッド毎に専有されており、複数のスレッドでデータが共有することはありません。ただし、スレッドセーフを保証しているØMQコンテキストは例外です
* ミューテックスやクリティカルセクション、セマフォなどの古典的な並行メカニズムは一度忘れて下さい。これらは、ØMQアプリケーションにおいてはアンチパターンです。
* ØMQコンテクストはプログラムの開始に生成し、プロセス内通信ソケットを行う全てのスレッドにこれを渡して下さい。
* アプリケーションを骨組みになるスレッドはattachedスレッドを作成して下さい。そしてプロセス内通信でペアのソケットを利用して親スレッドに接続して下さい。親スレッド側のソケットでbindして、子スレッド側のソケットで接続を行うのが定石です。
* 独立したタスクをシミュレートするには、detachedスレッドを利用し、独立したコンテキストを作成して下さい。通信方式はTCPを利用することで、後に大きな修正を行うこと無くスタンドアローンのプロセスに移行できます。
* スレッド間の全てのやり取りはあなたの定義したメッセージで行います。
* ØMQソケットはスレッドセーフではありませんのでØMQソケットを複数のスレッドで共用しないで下さい。ソケットを別のスレッドに移行することは技術的には可能ですが熟練技術が必要です。複数のスレッドで一つのソケットを扱う唯一の場面は魔法のようなガーベジコレクションを持った言語バインディングくらいです。

;If you need to start more than one proxy in an application, for example, you will want to run each in their own thread. It is easy to make the error of creating the proxy frontend and backend sockets in one thread, and then passing the sockets to the proxy in another thread. This may appear to work at first but will fail randomly in real use. Remember: Do not use or close sockets except in the thread that created them.

例えばアプリケーションの中で2つ以上のプロクシを動作させたい場合、それぞれのスレッドでプロキシーで動作させたいと思うかもしれません。
1つのスレッド内でエラーが発生した際に、ソケットを別のスレッドに渡すことが簡単にできてしまいますが、
実際にこれをやるとランダムに失敗します。
ソケットの生成を行ったスレッドでのみcloseを行うということを忘れないで下さい。

;If you follow these rules, you can quite easily build elegant multithreaded applications, and later split off threads into separate processes as you need to. Application logic can sit in threads, processes, or nodes: whatever your scale needs.

これらのルールに従った場合、とてもエレガントなマルチスレッドアプリケーションを構築できます。
後からスレッドではなくプロセスに分離することも可能です。
これはアプリケーションロジックはスレッドでもプロセスでも別ノードでも、適切な規模に合わせてスケールアップできるという事を意味します。

;ØMQ uses native OS threads rather than virtual "green" threads. The advantage is that you don't need to learn any new threading API, and that ØMQ threads map cleanly to your operating system. You can use standard tools like Intel's ThreadChecker to see what your application is doing. The disadvantages are that native threading APIs are not always portable, and that if you have a huge number of threads (in the thousands), some operating systems will get stressed.

ØMQは仮想的な「グリーンスレッド」ではなくOSのネイティブスレッドを使用しています。
これにはあなたが新しくスレッドAPIを学ばなくて良いという事や、ØMQスレッドは明確にOSのスレッドと対応するという利点があります。
また、IntelのThreadCheckerといった標準的なツールを利用してアプリケーションを観察することも出来ます。
欠点はネイティブのスレッドAPIは必ずしも移植性があるとは限らないという点です。
また、大量のスレッドを生成するとOSに負担が掛かってしまうでしょう。

;Let's see how this works in practice. We'll turn our old Hello World server into something more capable. The original server ran in a single thread. If the work per request is low, that's fine: one ØMQ thread can run at full speed on a CPU core, with no waits, doing an awful lot of work. But realistic servers have to do nontrivial work per request. A single core may not be enough when 10,000 clients hit the server all at once. So a realistic server will start multiple worker threads. It then accepts requests as fast as it can and distributes these to its worker threads. The worker threads grind through the work and eventually send their replies back.

それではこれらがどの様に動作するか実際に見て行きましょう。
ずっと前に見たHello Worldに幾つかの機能を追加します。
元々のサーバーはシングルスレッドで動作していました。
1リクエストで行う処理が少なければ、1コア分のCPUを利用して結構な処理を行うことができます。
しかし、実際のサーバーでは1リクエストで多くの処理を行います。
1万クライアントが同時にアクセスしてきた場合にはシングルコアでは不十分でしょう。
リクエストを受け付けたら即座にワーカースレッドに処理を分担し、最終的にはワーカースレッドが応答を返します。

;You can, of course, do all this using a proxy broker and external worker processes, but often it's easier to start one process that gobbles up sixteen cores than sixteen processes, each gobbling up one core. Further, running workers as threads will cut out a network hop, latency, and network traffic.

もちろん、プロキシーブローカーを利用して外部のワーカープロセスで全ての処理を行う事も可能ですが、16コアのCPUを使い切るために16個のプロセスを起動するよりはマルチスレッド化した1つのプロセスを起動するほうが簡単でしょう。
また、ワーカーをマルチスレッドで実行すると、余計なネットワークトラフィックやレイテンシが無くなります。

;The MT version of the Hello World service basically collapses the broker and workers into a single process:

Hello Worldサービスのマルチスレッド版にはブローカとワーカーの機能が一つのプロセスに押し込まれています。

~~~ {caption="mtserver: サービスのマルチスレッド化(C言語)"}
// Hello Worldサーバーのマルチスレッド化

#include "zhelpers.h"
#include <pthread.h>

static void *
worker_routine (void *context) {
    // Socket to talk to dispatcher
    void *receiver = zmq_socket (context, ZMQ_REP);
    zmq_connect (receiver, "inproc://workers");

    while (1) {
        char *string = s_recv (receiver);
        printf ("Received request: [%s]\n", string);
        free (string);
        // なんらかの仕事
        sleep (1);
        // Send reply back to client
        s_send (receiver, "World");
    }
    zmq_close (receiver);
    return NULL;
}

int main (void)
{
    void *context = zmq_ctx_new ();

    // Socket to talk to clients
    void *clients = zmq_socket (context, ZMQ_ROUTER);
    zmq_bind (clients, "tcp://*:5555");

    // Socket to talk to workers
    void *workers = zmq_socket (context, ZMQ_DEALER);
    zmq_bind (workers, "inproc://workers");

    // Launch pool of worker threads
    int thread_nbr;
    for (thread_nbr = 0; thread_nbr < 5; thread_nbr++) {
        pthread_t worker;
        pthread_create (&worker, NULL, worker_routine, context);
    }
    // Connect work threads to client threads via a queue proxy
    zmq_proxy (clients, workers, NULL);

    // We never get here, but clean up anyhow
    zmq_close (clients);
    zmq_close (workers);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

![サーバーのマルチスレッド化](images/fig20.eps)

;All the code should be recognizable to you by now. How it works:

もうコードを見れば何をやっているか理解できる頃でしょう。一応説明しておくと、

;* The server starts a set of worker threads. Each worker thread creates a REP socket and then processes requests on this socket. Worker threads are just like single-threaded servers. The only differences are the transport (inproc instead of tcp), and the bind-connect direction.
;* The server creates a ROUTER socket to talk to clients and binds this to its external interface (over tcp).
;* The server creates a DEALER socket to talk to the workers and binds this to its internal interface (over inproc).
;* The server starts a proxy that connects the two sockets. The proxy pulls incoming requests fairly from all clients, and distributes those out to workers. It also routes replies back to their origin.

* サーバーは複数のワーカースレッドを開始し、それぞれのワーカースレッドでREPソケットを作成してこのソケット経由でリクエストを処理します。ワーカースレッドはシングルスレッド版のサーバーと同様です。唯一の違いは転送方式がTCPではなくプロセス内通信であることと、bind-接続の方向性くらいです。
* サーバーはROUTERソケットを生成してbindを行い、外部インターフェースであるTCPを利用してクライアントと通信します。
* サーバーはDEALERソケットを生成してbindを行い、内部インターフェースであるプロセス内通信を利用してワーカースレッドと通信します。
* サーバーは２つのソケットをつなぐプロキシーを開始します。プロキシーは全てのクライアントから受け付けたリクエストをワーカーに均等に分担します。プロキシーは元のクライアントに対して応答を返します。

;Note that creating threads is not portable in most programming languages. The POSIX library is pthreads, but on Windows you have to use a different API. In our example, the pthread_create call starts up a new thread running the worker_routine function we defined. We'll see in Chapter 3 - Advanced Request-Reply Patterns how to wrap this in a portable API.

スレッドの生成は多くのプログラミング言語で移植性が無いことに注意して下さい。
POSIXライブラリにpthreadsがありますが、Windowsでは異なるAPIを使わなくてはなりません。
このサンプルコードでは、`pthread_create()`を呼び出して定義されたワーカー処理の関数を実行しています。
第3章「リクエスト・応答パターンの応用」では移植性のあるAPIでこれをラップする方法を見ていきます。

;Here the "work" is just a one-second pause. We could do anything in the workers, including talking to other nodes. This is what the MT server looks like in terms of ØMQ sockets and nodes. Note how the request-reply chain is REQ-ROUTER-queue-DEALER-REP.
ここでの「仕事」は単に1秒間停止しているだけです。
ワーカーでは、他のノードと通信することを含めてあらゆる処理を行うことが出来ます。
これはマルチスレッドサーバーがØMQソケットやノードと同等である事を表しています。
リクエスト・応答の経路はREQ-ROUTER-queue-DEALER-REPを経由します。

## スレッド間の通知(PAIRソケット)
;When you start making multithreaded applications with ØMQ, you'll encounter the question of how to coordinate your threads. Though you might be tempted to insert "sleep" statements, or use multithreading techniques such as semaphores or mutexes, the only mechanism that you should use are ØMQ messages. Remember the story of The Drunkards and The Beer Bottle.

実際にØMQでマルチスレッドアプリケーションを作り始めると、スレッド同士の連携をどの様に行うかという問題に遭遇するでしょう。
この時あなたはつい魔が差してsleep命令を入れたり、マルチスレッドのテクニックであるセマフォやミューテックスを使用したくなるかもしれませんが、この時使うべき手段はØMQメッセージだけです。酔っぱらいとビール瓶の話を思い出して下さい。

;Let's make three threads that signal each other when they are ready. In this example, we use PAIR sockets over the inproc transport:

それでは、3つのスレッドでお互いに準備完了を通知するコードを書いてみましょう。
この例ではプロセス内通信を行うPAIRソケットを利用します。

~~~ {caption="mtrelay: relayのマルチスレッド化(C言語)"}
// リレーのマルチスレッド化

#include "zhelpers.h"
#include <pthread.h>

static void *
step1 (void *context) {
    // Connect to step2 and tell it we're ready
    void *xmitter = zmq_socket (context, ZMQ_PAIR);
    zmq_connect (xmitter, "inproc://step2");
    printf ("Step 1 ready, signaling step 2\n");
    s_send (xmitter, "READY");
    zmq_close (xmitter);

    return NULL;
}

static void *
step2 (void *context) {
    // Bind inproc socket before starting step1
    void *receiver = zmq_socket (context, ZMQ_PAIR);
    zmq_bind (receiver, "inproc://step2");
    pthread_t thread;
    pthread_create (&thread, NULL, step1, context);

    // Wait for signal and pass it on
    char *string = s_recv (receiver);
    free (string);
    zmq_close (receiver);

    // Connect to step3 and tell it we're ready
    void *xmitter = zmq_socket (context, ZMQ_PAIR);
    zmq_connect (xmitter, "inproc://step3");
    printf ("Step 2 ready, signaling step 3\n");
    s_send (xmitter, "READY");
    zmq_close (xmitter);

    return NULL;
}

int main (void)
{
    void *context = zmq_ctx_new ();

    // Bind inproc socket before starting step2
    void *receiver = zmq_socket (context, ZMQ_PAIR);
    zmq_bind (receiver, "inproc://step3");
    pthread_t thread;
    pthread_create (&thread, NULL, step2, context);

    // Wait for signal
    char *string = s_recv (receiver);
    free (string);
    zmq_close (receiver);

    printf ("Test successful!\n");
    zmq_ctx_destroy (context);
    return 0;
}
~~~

![The Relay Race](images/fig21.eps)

This is a classic pattern for multithreading with ØMQ:

ØMQのマルチスレッドの古典的なパターンは以下の通りです。

;* Two threads communicate over inproc, using a shared context.
;* The parent thread creates one socket, binds it to an inproc: endpoint, and //then starts the child thread, passing the context to it.
;* The child thread creates the second socket, connects it to that inproc: endpoint, and //then signals to the parent thread that it's ready.

* 2つのスレッドで共有しているコンテキストを利用してプロセス内通信を行います。
* 親スレッドはソケットを1つ作成し、プロセス内通信のエンドポイントとしてbindし、コンテキストを渡して子スレッドを起動します。
* 子スレッドは2つ目のソケットを作成し、親スレッドのエンドポイントに接続します。そして親スレッドに準備完了を通知します。

;Note that multithreading code using this pattern is not scalable out to processes. If you use inproc and socket pairs, you are building a tightly-bound application, i.e., one where your threads are structurally interdependent. Do this when low latency is really vital. The other design pattern is a loosely bound application, where threads have their own context and communicate over ipc or tcp. You can easily break loosely bound threads into separate processes.

マルチスレッドのコードでこのパターンを利用すると外部プロセスに拡張出来ないことに注意して下さい。
プロセス内通信でペアソケットを利用すると、例えば片方のスレッドが構造的に相互依存している様な結合の強いアプリケーションを構築できます。
低レイテンシを維持することがが極めて重要な場合にはこれは最適です。
他のデザインパターンはスレッドは独自のコンテキストを持ち、IPCやTCPを経由して通信を行うので疎結合なアプリケーションに向いています。
疎結合なスレッドは簡単に別プロセスに分離することができます。

;This is the first time we've shown an example using PAIR sockets. Why use PAIR? Other socket combinations might seem to work, but they all have side effects that could interfere with signaling:

PAIRソケットを利用したサンプルコードはこれが初めてです。
ここでPAIRソケットを使った理由はなんだと思いますか?
他のソケットの組み合わせでも上手く動作するように見えますが、これらを通知のインターフェースとして利用すると副作用があります。

;* You can use PUSH for the sender and PULL for the receiver. This looks simple and will work, but remember that PUSH will distribute messages to all available receivers. If you by accident start two receivers (e.g., you already have one running and you start a second), you'll "lose" half of your signals. PAIR has the advantage of refusing more than one connection; the pair is exclusive.
;* You can use DEALER for the sender and ROUTER for the receiver. ROUTER, however, wraps your message in an "envelope", meaning your zero-size signal turns into a multipart message. If you don't care about the data and treat anything as a valid signal, and if you don't read more than once from the socket, that won't matter. If, however, you decide to send real data, you will suddenly find ROUTER providing you with "wrong" messages. DEALER also distributes outgoing messages, giving the same risk as PUSH.
;* You can use PUB for the sender and SUB for the receiver. This will correctly deliver your messages exactly as you sent them and PUB does not distribute as PUSH or DEALER do. However, you need to configure the subscriber with an empty subscription, which is annoying.

* 送信側でPUSH、受信側でPULLソケットを使用するとします。これは単純に動作するように見えますがPUSHはメッセージを全ての受信者に配信する事を思い出して下さい。受信者が2つ居て、片方が起動していない場合、半分の通知が失われてしまうことになります。PAIRは排他的であり2つ以上の接続を許可しませんのでこの様な事が起こりません。
* 送信側でDEALER、受信側でROUTERソケットを使用するとします。ROUTERはメッセージをエンベロープに包装します。これはサイズが0の通知用メッセージであってもマルチパートメッセージに包まれてしまう事を意味します。メッセージの内容に関して関知せずソケットからデータを読み取らない場合は問題ありませんが、内容を持ったデータを送信する事になった場合、ROUTERから誤ったデータを読み取ってしまいます。DEALERはソケットを通知で利用する際にはPUSHソケットと同様にリスクがあります。
* 送信側でPUB、受信側でSUBソケットを使用するとします。PUSHやDEALERやと異なり、この場合完全に正しくメッセージを配送することができますが、空のメッセージを受信できるようにサブスクライバ側の設定を行わなければならないのが面倒です。

;For these reasons, PAIR makes the best choice for coordination between pairs of threads.

これらの理由により、スレッド間の連携を行うためにはPAIRソケットを利用するのが最適です。

## ノードの連携
;When you want to coordinate a set of nodes on a network, PAIR sockets won't work well any more. This is one of the few areas where the strategies for threads and nodes are different. Principally, nodes come and go whereas threads are usually static. PAIR sockets do not automatically reconnect if the remote node goes away and comes back.

ネットワーク上のノードを連携する際、PAIRソケットでは上手く動作しません。
スレッドとノードの戦略が異なっている部分の1つです。
ノードは落ちてたり動いてたりするのに対し、スレッドは固定的であることが主な違いです。PAIRソケットは接続相手と一時的に接続が切れた場合に自動的に再接続を行いません。

![Pub-Sub Synchronization](images/fig22.eps)

;The second significant difference between threads and nodes is that you typically have a fixed number of threads but a more variable number of nodes. Let's take one of our earlier scenarios (the weather server and clients) and use node coordination to ensure that subscribers don't lose data when starting up.

スレッドとノードで異なる2つ目の重要な点は、一般的にスレッドの数は固定であるのに対してノードの数は可変である事です。
以前見た気象情報サーバーとクライアントのシナリオで、起動時にデータを喪失しないよう確実に配信を行えるようノードの連携を行ってみましょう。

;This is how the application will work:

このアプリケーションは以下のように動作します。

;* The publisher knows in advance how many subscribers it expects. This is just a magic number it gets from somewhere.
;* The publisher starts up and waits for all subscribers to connect. This is the node coordination part. Each subscriber subscribes and then tells the publisher it's ready via another socket.
;* When the publisher has all subscribers connected, it starts to publish data.

* パブリッシャーは接続してくるサブスクライバー数を想定しているとします。これはとりあえずハードコーディングしていますが何でも構いません。
* パブリッシャーが起動すると、想定している全てのサブスクライバーが接続してくるまで待ちます。ここからがノードの連携処理で、各サブスクライバーはパブリッシャーに対してもう一方のSUBソケットが準備完了していることを通知します。
* 全てのサブスクライバーが接続したらデータの配信を開始します。

;In this case, we'll use a REQ-REP socket flow to synchronize subscribers and publisher. Here is the publisher:

このケースでは、サブスクライバーとパブリッシャーの同期を行うためにREQ-REPソケットを利用します。
以下はパブリッシャーのコードです。

~~~ {caption="syncpub: Synchronized publisher in C"}
// Synchronized publisher

#include "zhelpers.h"
#define SUBSCRIBERS_EXPECTED 10 //// We wait for 10 subscribers //

int main (void)
{
    void *context = zmq_ctx_new ();

    // Socket to talk to clients
    void *publisher = zmq_socket (context, ZMQ_PUB);

    int sndhwm = 1100000;
    zmq_setsockopt (publisher, ZMQ_SNDHWM, &sndhwm, sizeof (int));

    zmq_bind (publisher, "tcp://*:5561");

    // Socket to receive signals
    void *syncservice = zmq_socket (context, ZMQ_REP);
    zmq_bind (syncservice, "tcp://*:5562");

    // Get synchronization from subscribers
    printf ("Waiting for subscribers\n");
    int subscribers = 0;
    while (subscribers < SUBSCRIBERS_EXPECTED) {
        // - wait for synchronization request
        char *string = s_recv (syncservice);
        free (string);
        // - send synchronization reply
        s_send (syncservice, "");
        subscribers++;
    }
    // Now broadcast exactly 1M updates followed by END
    printf ("Broadcasting messages\n");
    int update_nbr;
    for (update_nbr = 0; update_nbr < 1000000; update_nbr++)
        s_send (publisher, "Rhubarb");

    s_send (publisher, "END");

    zmq_close (publisher);
    zmq_close (syncservice);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

;And here is the subscriber:

こちらはサブスクライバーです。

~~~ {caption="syncsub: Synchronized subscriber in C"}
// Synchronized subscriber

#include "zhelpers.h"

int main (void)
{
    void *context = zmq_ctx_new ();

    // First, connect our subscriber socket
    void *subscriber = zmq_socket (context, ZMQ_SUB);
    zmq_connect (subscriber, "tcp://localhost:5561");
    zmq_setsockopt (subscriber, ZMQ_SUBSCRIBE, "", 0);

    // 0MQ is so fast, we need to wait a while…
    sleep (1);

    // Second, synchronize with publisher
    void *syncclient = zmq_socket (context, ZMQ_REQ);
    zmq_connect (syncclient, "tcp://localhost:5562");

    // - send a synchronization request
    s_send (syncclient, "");

    // - wait for synchronization reply
    char *string = s_recv (syncclient);
    free (string);

    // Third, get our updates and report how many we got
    int update_nbr = 0;
    while (1) {
        char *string = s_recv (subscriber);
        if (strcmp (string, "END") == 0) {
            free (string);
            break;
        }
        free (string);
        update_nbr++;
    }
    printf ("Received %d updates\n", update_nbr);

    zmq_close (subscriber);
    zmq_close (syncclient);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

;This Bash shell script will start ten subscribers and then the publisher:

以下のBashのシェルスクリプトで10個のサブスクライバーとパブリッシャーを起動します。

~~~
echo "Starting subscribers..."
for ((a=0; a<10; a++)); do
    syncsub &
done
echo "Starting publisher..."
syncpub
~~~

;Which gives us this satisfying output:

上手く行けば以下の出力が得られるはずです。

~~~
Starting subscribers...
Starting publisher...
Received 1000000 updates
Received 1000000 updates
...
Received 1000000 updates
Received 1000000 updates
~~~

;We can't assume that the SUB connect will be finished by the time the REQ/REP dialog is complete. There are no guarantees that outbound connects will finish in any order whatsoever, if you're using any transport except inproc. So, the example does a brute force sleep of one second between subscribing, and sending the REQ/REP synchronization.

REQ/REPのやり取りが完了した時点ではSUBソケットの接続が完了しているとは限りません。
転送方式にプロセス内通信を利用している場合を除き、接続完了の順序は保証されていません。
そのため、SUBソケットの接続後、REQ/REP同期を行うまでの間に1秒間の強制的なsleepを行っています。

;A more robust model could be:

より確実なモデルにする為には、

;* Publisher opens PUB socket and starts sending "Hello" messages (not data).
;* Subscribers connect SUB socket and when they receive a Hello message they tell the publisher via a REQ/REP socket pair.
;* When the publisher has had all the necessary confirmations, it starts to send real data.

* パブリッシャーはPUBソケットをbindし、実際のデータではない「Hello」メッセージを送信します。
* サブスクライバーはSUBソケットで接続を行い「Hello」メッセージを受信した時にREQ/REPソケットペアを経由して受信に成功した旨をパブリッシャーに伝えます。
* そうして、パブリッシャーが全ての確認メッセージを確認した後に、実際のデータの配信を開始します。

## ゼロコピー
;ØMQ's message API lets you can send and receive messages directly from and to application buffers without copying data. We call this zero-copy, and it can improve performance in some applications.

ØMQのメッセージAPIはアプリケーションのバッファからコピーを行わずに直接送受信を行うことが出来ます。私達はこれをゼロコピーと呼んでいて、アプリケーションのパフォーマンスを改善する事ができます。

;You should think about using zero-copy in the specific case where you are sending large blocks of memory (thousands of bytes), at a high frequency. For short messages, or for lower message rates, using zero-copy will make your code messier and more complex with no measurable benefit. Like all optimizations, use this when you know it helps, and measure before and after.

巨大なメモリブロックを頻繁に送信する様な特定のケースでは、ゼロコピーを利用することを検討すると良いでしょう。
ただし、小さいメッセージや送受信が低頻度であればゼロコピーはコードが複雑になるだけで有意な効果を得られないかもしれません。

;To do zero-copy, you use zmq_msg_init_data() to create a message that refers to a block of data already allocated with malloc() or some other allocator, and then you pass that to zmq_msg_send(). When you create the message, you also pass a function that ØMQ will call to free the block of data, when it has finished sending the message. This is the simplest example, assuming buffer is a block of 1,000 bytes allocated on the heap:

ゼロコピーを行う為には`zmq_msg_init_data()`関数に`malloc()`やその他のメモリアロケータで確保したメモリブロックを渡してメッセージオブジェクトを生成します。
そして、そのメッセージを`zmq_msg_send()`に渡して送信します。
メッセージオブジェクトを生成する際、メッセージの送信完了時にメモリを開放する為の関数も同時に渡します。
以下はヒープ上に1,000バイトのバッファを確保する単純なサンプルコードです。

~~~
void my_free (void *data, void *hint) {
    free (data);
}
// Send message from buffer, which we allocate and 0MQ will free for us
zmq_msg_t message;
zmq_msg_init_data (&message, buffer, 1000, my_free, NULL);
zmq_msg_send (&message, socket, 0);
~~~

;Note that you don't call zmq_msg_close() after sending a message—libzmq will do this automatically when it's actually done sending the message.

メッセージの送信後に`zmq_msg_close()`を呼んではならないことに注意して下さい。
libzmqはメッセージを送信した後は自動的にこれを行います。

;There is no way to do zero-copy on receive: ØMQ delivers you a buffer that you can store as long as you wish, but it will not write data directly into application buffers.

受信時にゼロコピーを行う方法はありません。
ØMQの受信バッファは望む限りいつまでも残しておくことができますが、ØMQはアプリケーションのバッファに直接書き込む事はありません。

;On writing, ØMQ's multipart messages work nicely together with zero-copy. In traditional messaging, you need to marshal different buffers together into one buffer that you can send. That means copying data. With ØMQ, you can send multiple buffers coming from different sources as individual message frames. Send each field as a length-delimited frame. To the application, it looks like a series of send and receive calls. But internally, the multiple parts get written to the network and read back with single system calls, so it's very efficient.

ゼロコピーはØMQのマルチパートメッセージの送信時に適しています。
従来のメッセージングでは複数のバッファを一つのバッファーにまとめて送信する必要がありました。これはデータをコピーしなければならないことを意味しています。
ØMQでは個別のメッセージフレームを元にしたマルチパートメッセージを送信することが可能です。
アプリケーションから見ると一連の送受信呼び出しを行っているように見えますが、
内部的には1度のシステムコール呼び出しでマルチパートメッセージを呼び出してネットワークに送信するため、非常に効率的です。

## Pub-Subメッセージエンベロープ
;In the pub-sub pattern, we can split the key into a separate message frame that we call an envelope. If you want to use pub-sub envelopes, make them yourself. It's optional, and in previous pub-sub examples we didn't do this. Using a pub-sub envelope is a little more work for simple cases, but it's cleaner especially for real cases, where the key and the data are naturally separate things.

pub-subパターンでは、フィルタの対象であるキーをエンベロープと呼ばれるメッセージフレームに分けて送信することができます。
pub-subエンベロープを利用する場合は明示的にこのメッセージフレームを生成して下さい。
この機能は任意ですので以前のpub-subのサンプルコードでは利用しませんでした。
pub-subエンベロープを利用するには、ちょっとしたコードを追加する必要があります。
実際のコードを見れば直ぐに理解できると思いますが、キーとデータが別々のメッセージフレームに別けているだけです。

![Pub-Sub Envelope with Separate Key](images/fig23.eps)

;Recall that subscriptions do a prefix match. That is, they look for "all messages starting with XYZ". The obvious question is: how to delimit keys from data so that the prefix match doesn't accidentally match data. The best answer is to use an envelope because the match won't cross a frame boundary. Here is a minimalist example of how pub-sub envelopes look in code. This publisher sends messages of two types, A and B.

サブスクライバーは前方一致でフィルタリングを行っている事を思い出して下さい。
誤ってデータと一致しないようにキーとデータをどうやって区切るのか、という疑問を抱くのは当然のことです。
最適な解決方法はエンベロープを使うことです。フレーム境界を超えて一致することはありません。
以下はpub-subエンベロープを利用する最小のサンプルコードです。
パブリッシャーは2種類のタイプのメッセージ(AとB)を送信しています。

;The envelope holds the message type:

エンベロープはメッセージ種別を保持しています。

~~~ {caption="psenvpub: Pub-Sub envelope publisher in C"}
// Pubsub envelope publisher
// Note that the zhelpers.h file also provides s_sendmore

#include "zhelpers.h"

int main (void)
{
    // Prepare our context and publisher
    void *context = zmq_ctx_new ();
    void *publisher = zmq_socket (context, ZMQ_PUB);
    zmq_bind (publisher, "tcp://*:5563");

    while (1) {
        // Write two messages, each with an envelope and content
        s_sendmore (publisher, "A");
        s_send (publisher, "We don't want to see this");
        s_sendmore (publisher, "B");
        s_send (publisher, "We would like to see this");
        sleep (1);
    }
    // We never get here, but clean up anyhow
    zmq_close (publisher);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

;The subscriber wants only messages of type B:

サブスクライバーはメッセージ種別Bのみを受信します。

~~~ {caption="psenvsub: Pub-Sub envelope subscriber in C"}
// Pubsub envelope subscriber

#include "zhelpers.h"

int main (void)
{
    // Prepare our context and subscriber
    void *context = zmq_ctx_new ();
    void *subscriber = zmq_socket (context, ZMQ_SUB);
    zmq_connect (subscriber, "tcp://localhost:5563");
    zmq_setsockopt (subscriber, ZMQ_SUBSCRIBE, "B", 1);

    while (1) {
        // Read envelope with address
        char *address = s_recv (subscriber);
        // Read message contents
        char *contents = s_recv (subscriber);
        printf ("[%s] %s\n", address, contents);
        free (address);
        free (contents);
    }
    // We never get here, but clean up anyhow
    zmq_close (subscriber);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

;When you run the two programs, the subscriber should show you this:

2つのプログラムを動作させると、サブスクライバー側では以下の結果が得られるでしょう。

~~~
[B] We would like to see this
[B] We would like to see this
[B] We would like to see this
...
~~~

;This example shows that the subscription filter rejects or accepts the entire multipart message (key plus data). You won't get part of a multipart message, ever. If you subscribe to multiple publishers and you want to know their address so that you can send them data via another socket (and this is a typical use case), create a three-part message.

このサンプルコードではキーとデータを含むマルチパートメッセージの取捨選択を行っています。
マルチパートメッセージの一部を取得する必要はありません。
複数のパブリッシャーから更新情報を受け取っている場合、メッセージの送信元を識別したいと思うかもしれません。そんな時は3つで構成されるマルチパートメッセージを作成しください。

![Pub-Sub Envelope with Sender Address](images/fig24.eps)

## 満杯マーク
;When you can send messages rapidly from process to process, you soon discover that memory is a precious resource, and one that can be trivially filled up. A few seconds of delay somewhere in a process can turn into a backlog that blows up a server unless you understand the problem and take precautions.

プロセスからプロセスに大量のメッセージを送信する際、メモリが貴重な資源であることに気がつくでしょう。
問題を理解し対策を講じない限り、プロセスのバックログは膨れ上がり、数秒間の遅延が発生引き起こすでしょう。

;The problem is this: imagine you have process A sending messages at high frequency to process B, which is processing them. Suddenly B gets very busy (garbage collection, CPU overload, whatever), and can't process the messages for a short period. It could be a few seconds for some heavy garbage collection, or it could be much longer, if there's a more serious problem. What happens to the messages that process A is still trying to send frantically? Some will sit in B's network buffers. Some will sit on the Ethernet wire itself. Some will sit in A's network buffers. And the rest will accumulate in A's memory, as rapidly as the application behind A sends them. If you don't take some precaution, A can easily run out of memory and crash.

プロセスAからプロセスBに対して短期間に大量のメッセージを送信した場合を想像して下さい
プロセスBは突然CPU負荷やガーベジコレクションなどの理由により高負荷に陥り、メッセージを処理出来なくなったとします。
重いガーベジコレクションは数秒かかるでしょうし、深刻な問題が発生した場合はもっと時間がかかるかもしれません。
プロセスAが必死にメッセージを送り続けた場合メッセージはどうなるでしょうか。
幾つかはB側のネットワークバッファにとどまります。
幾つかはイーサネット回線上にとどまるでしょう。
幾つかはA側のネットワークバッファにとどまります。
残りの部分は後ほど迅速に再送できるようにA側のメモリにとどまります。
何らかの対応を行わなければメモリ不足に陥り、クラッシュしてしまうでしょう。

;It is a consistent, classic problem with message brokers. What makes it hurt more is that it's B's fault, superficially, and B is typically a user-written application which A has no control over.

これは、メッセージブローカーが持つ古典的な問題と同様です。
この問題の痛い所は、プロセスBの障害によってプロセスAが制御不能に陥ってしまうことです。

;What are the answers? One is to pass the problem upstream. A is getting the messages from somewhere else. So tell that process, "Stop!" And so on. This is called flow control. It sounds plausible, but what if you're sending out a Twitter feed? Do you tell the whole world to stop tweeting while B gets its act together?

解決方法のひとつは問題を上流に伝えることです。
プロセスAに対して「送信を止めろ」というようなメッセージを何らかの方法で伝えてやります。
[TODO]
これはフロー制御と呼ばれています。
この方法はもっともらしく見えますが、例えばTwitterのタイムラインで全世界に対して「つぶやきを止めろ」という事は妥当でしょうか?

;Flow control works in some cases, but not in others. The transport layer can't tell the application layer to "stop" any more than a subway system can tell a large business, "please keep your staff at work for another half an hour. I'm too busy". The answer for messaging is to set limits on the size of buffers, and then when we reach those limits, to take some sensible action. In some cases (not for a subway system, though), the answer is to throw away messages. In others, the best strategy is to wait.[TODO]

フロー制御は場合によっては上手く行きますが、そうでない時もあります。
通信レイヤはアプリケーションレイヤに対して「止めろ」というようなことは出来ません。
地下鉄はよく「仕事を始めるのを30分送らせてくれ」といった事を行ってきますが、迷惑な話です。
メッセージングでの解決方法はバッファのサイズに上限を設定し、この上限に達した場合に合理的な動作を行います。
あるケースではメッセージを投げ捨ててしまう方が良い場合もあるし、ある時は待つことが最良の戦略である場合もあります。

;ØMQ uses the concept of HWM (high-water mark) to define the capacity of its internal pipes. Each connection out of a socket or into a socket has its own pipe, and HWM for sending, and/or receiving, depending on the socket type. Some sockets (PUB, PUSH) only have send buffers. Some (SUB, PULL, REQ, REP) only have receive buffers. Some (DEALER, ROUTER, PAIR) have both send and receive buffers.

ØMQはHWM(満杯マークという)概念を用いてパイプの容量を定義します。
各コネクションはソケットの外部か内部に個別のパイプを持っていて、HWMは送信時と受信時にソケット種別に応じて制限を掛けます。
PUB, PUSHなどのソケットは送信バッファのみを持っていて、SUB, PULL, REQ, REPなどのバッファは受信バッファを持っています。
DEALER, ROUTER, PAIRなどのバッファに関しては送信と受信の両方バッファを持っています。

;In ØMQ v2.x, the HWM was infinite by default. This was easy but also typically fatal for high-volume publishers. In ØMQ v3.x, it's set to 1,000 by default, which is more sensible. If you're still using ØMQ v2.x, you should always set a HWM on your sockets, be it 1,000 to match ØMQ v3.x or another figure that takes into account your message sizes and expected subscriber performance.

ØMQv2.xでは、HWMは既定で無制限でした。
これは単純でしたが大量配信を行うパブリッシャーにとって致命的でした。
ØMQ v3.xでは規定で1,000という合理的な値が設定されています。
もしあなたがまだØMQ v2.xを利用しているのなら、常にHWMに1,000を設定しておいたほうが良いでしょう。
[TODO]

;When your socket reaches its HWM, it will either block or drop data depending on the socket type. PUB and ROUTER sockets will drop data if they reach their HWM, while other socket types will block. Over the inproc transport, the sender and receiver share the same buffers, so the real HWM is the sum of the HWM set by both sides.

ソケットがHWMの上限に達した場合ソケット種別に応じてメッセージをブロックするか捨てるかが決まります。
HWMの上限に達した際、PUBとROUTERソケットはメッセージを捨て、その他のソケット種別の場合ブロックします。
プロセス内通信を行う場合、送信側と受信側で同じバッファを共有していますので両サイドで設定したHWMの合計が実際のHWMの上限となります。

;Lastly, the HWMs are not exact; while you may get up to 1,000 messages by default, the real buffer size may be much lower (as little as half), due to the way libzmq implements its queues.

最後に、HWMは正確ではありません。
デフォルトでは1,000個までのメッセージを受け取るはずですが、libzmqはキューとして実装されているので実際のバッファーサイズはこれより半分程度小さいことがあります。

## メッセージ喪失問題の解決方法
;As you build applications with ØMQ, you will come across this problem more than once: losing messages that you expect to receive. We have put together a diagram that walks through the most common causes for this.

ØMQでアプリケーションを開発していると、受信するはずメッセージが喪失してしまうという問題に遭遇するでしょう。
そこで私達はよくあるメッセージ喪失問題の解決フローをまとめました。

![Missing Message Problem Solver](images/fig25.eps)

;Here's a summary of what the graphic says:

この図は以下のことを表しています。

;* On SUB sockets, set a subscription using zmq_setsockopt() with ZMQ_SUBSCRIBE, or you won't get messages. Because you subscribe to messages by prefix, if you subscribe to "" (an empty subscription), you will get everything.

;* If you start the SUB socket (i.e., establish a connection to a PUB socket) after the PUB socket has started sending out data, you will lose whatever it published before the connection was made. If this is a problem, set up your architecture so the SUB socket starts first, then the PUB socket starts publishing.

;* Even if you synchronize a SUB and PUB socket, you may still lose messages. It's due to the fact that internal queues aren't created until a connection is actually created. If you can switch the bind/connect direction so the SUB socket binds, and the PUB socket connects, you may find it works more as you'd expect.

;* If you're using REP and REQ sockets, and you're not sticking to the synchronous send/recv/send/recv order, ØMQ will report errors, which you might ignore. Then, it would look like you're losing messages. If you use REQ or REP, stick to the send/recv order, and always, in real code, check for errors on ØMQ calls.

;* If you're using PUSH sockets, you'll find that the first PULL socket to connect will grab an unfair share of messages. The accurate rotation of messages only happens when all PULL sockets are successfully connected, which can take some milliseconds. As an alternative to PUSH/PULL, for lower data rates, consider using ROUTER/DEALER and the load balancing pattern.

;* If you're sharing sockets across threads, don't. It will lead to random weirdness, and crashes.

;* If you're using inproc, make sure both sockets are in the same context. Otherwise the connecting side will in fact fail. Also, bind first, then connect. inproc is not a disconnected transport like tcp.

;* If you're using ROUTER sockets, it's remarkably easy to lose messages by accident, by sending malformed identity frames (or forgetting to send an identity frame). In general setting the ZMQ_ROUTER_MANDATORY option on ROUTER sockets is a good idea, but do also check the return code on every send call.

;* Lastly, if you really can't figure out what's going wrong, make a minimal test case that reproduces the problem, and ask for help from the ØMQ community.

* SUBソケットは、`zmq_setsockopt()`でZMQ_SUBSCRIBEを設定しなければ更新メッセージを受信できません。これは意図的な仕様です、理由は更新メッセージはプレフィックスでフィルタリングを行っているため、既定のフィルタ「」(空文字列)では全てを受信してしまうからです。

* SUBソケットがPUBソケットに対して接続を確立した後に、PUBソケットがメッセージを送信を開始した場合でもメッセージを失ってしまいます。これが問題になる場合、まず最初にSUBソケットを開始して、その後、PUBソケットで配信するようなアーキテクチャを構成しなければなりません。

* SUBソケットとPUBソケットを同期させる場合でもメッセージを喪失してしまう可能性があります。これは、実際に接続が行われるまで内部キューが作成されていないという事実によるものです。bindと接続の方向性は切り替えることができますのでPUBソケットから接続を行った場合、さらに幾つかの期待通りに動作しない場合があるでしょう。

* REPソケットとREQソケットを利用していて、送信、受信、送信、受信という順番で同期が行われていない場合、ØMQはメッセージを無視ししてエラーを報告するでしょう。この場合でも、メッセージの喪失した様に見えます。REQやREPソケットを利用する場合は、送信/受信の順番を常にコードの中で固定し、エラーを確認するようにしてください。

* PUSHソケットを利用してメッセージを分配する場合、最初に接続したPULLソケットは不公平な数のメッセージを受け取るかもしれません。メッセージの分配は正確にはPULLソケットが接続に成功して数ミリ秒掛かってしまうからです。少ない配信頻度でもっと正確な分配を行いたい場合はROUTER/DEALERのロードバランシングパターンを利用して下さい。

* 複数のスレッドでソケットを共有している場合…、そんなことをしてはいけません、これをやるとランダムで奇妙なクラッシュを引き起こしてしまうでしょう。

* プロセス内通信を行っている場合、共有したひとつのコンテキストで両方のソケットを作成してください。そうしないと接続側は常に失敗します。またプロセス内通信はTCPのような非接続通信方式と異なりますので最初にbindを行なってから接続してください。

* ROUTERソケットで不正な形式のidentityフレームを送信してしまったり、identityフレームを送信し忘れたりしてしまうようなアクシデントによりメッセージを喪失しやすくなります。一般的に、ZMQ_ROUTER_MANDATORYオプションをROUTERソケットに設定することは良いアイディアですが、送信API呼び出しの返り値を確認するようにしてください。

* 最後に、なぜうまく行かないのか判断できない場合、問題を再現させる小さなテストコードを書いてコミュニティで質問してみるとよいでしょう。


