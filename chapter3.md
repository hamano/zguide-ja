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

それでは、REQ-REPソケットペアを拡張したROUTER-DEALERプロキシーで応答エンベロープにどの様な影響があるか見て行きましょう。
これは第2章の「ソケットとパターン」で既に見た、拡張されたリクエスト・応答パターンと同じ仕組みで、プロキシーを幾つでも挿入することが出来ます。

![拡張されたリクエスト・応答パターン](images/fig27.eps)

;The proxy does this, in pseudo-code:

プロキシーは擬似コードで以下の様に動作します。

~~~
prepare context, frontend and backend sockets
while true:
    poll on both sockets
    if frontend had input:
        read all frames from frontend
        send to backend
    if backend had input:
        read all frames from backend
        send to frontend
~~~

;The ROUTER socket, unlike other sockets, tracks every connection it has, and tells the caller about these. The way it tells the caller is to stick the connection identity in front of each message received. An identity, sometimes called an address, is just a binary string with no meaning except "this is a unique handle to the connection". Then, when you send a message via a ROUTER socket, you first send an identity frame.

ROUTERソケットは他のソケットとは異なり、全ての接続をトラッキングして接続元を通知します。
メッセージを受信すると、メッセージの頭に接続IDを頭に付与する事で接続元を通知します。
このIDはアドレスとも言われ、コネクションに対するユニークなIDになります。。
ROUTERソケット経由でメッセージを送信すると、まずこのIDフレームが送信されます。

;The zmq_socket() man page describes it thus:

`zmq_socket()`のmanページには以下のように書かれています。

;> When receiving messages a ZMQ_ROUTER socket shall prepend a message part containing the identity of the originating peer to the message before passing it to the application. Messages received are fair-queued from among all connected peers. When sending messages a ZMQ_ROUTER socket shall remove the first part of the message and use it to determine the identity of the peer the message shall be routed to.

> ZMQ_ROUTERソケットがメッセージを受信すると、メッセージフレームの先頭に元々の接続IDを追加します。
> 受信したメッセージは全ての接続相手の中から均等にキューイングします。
> ZMQ_ROUTERソケットから送信を行う時、最初のメッセージフレームのIDをを削除してメッセージをルーティングします。

;As a historical note, ØMQ v2.2 and earlier use UUIDs as identities, and ØMQ v3.0 and later use short integers. There's some impact on network performance, but only when you use multiple proxy hops, which is rare. Mostly the change was to simplify building libzmq by removing the dependency on a UUID library.

歴史的な情報ですが、ØMQ v2.2以前はこのIDにUUIDを利用していましたが、ØMQ 3.0以降からは短い整数を利用しています。
これはネットワークパフォーマンスに少なからず影響を与えますが、多段のプロキシーを利用している場合は影響は微々たるものでしょう。
最も大きな影響はlibzmqがUUIDライブラリに依存しなくなったことくらいです。

;Identies are a difficult concept to understand, but it's essential if you want to become a ØMQ expert. The ROUTER socket invents a random identity for each connection with which it works. If there are three REQ sockets connected to a ROUTER socket, it will invent three random identities, one for each REQ socket.

IDは理解しにくい概念ですが、ØMQのエキスパートになる為には不可欠です。
ROUTERソケットはコネクション毎にランダムなIDを生成します。
ROUTERソケットに対して3つのREQソケットが接続したとすると、それぞれ異なる3つのIDが生成されるでしょう。

;So if we continue our worked example, let's say the REQ socket has a 3-byte identity ABC. Internally, this means the ROUTER socket keeps a hash table where it can search for ABC and find the TCP connection for the REQ socket.

引き続き動作の説明を続けると、REQソケットが3バイトのID「ABC」を持っていたとすると、内部的には、ROUTERソケットは「ABC」というキーワードで検索してTCPコネクションを得ることのできるハッシュテーブルを持っていることを意味します。

;When we receive the message off the ROUTER socket, we get three frames.

ROUTERソケットからメッセージを受信すると3つのフレームを受け取ることになります。

![アドレス付きのリクエスト](images/fig28.eps)

;The core of the proxy loop is "read from one socket, write to the other", so we literally send these three frames out on the DEALER socket. If you now sniffed the network traffic, you would see these three frames flying from the DEALER socket to the REP socket. The REP socket does as before, strips off the whole envelope including the new reply address, and once again delivers the "Hello" to the caller.

プロキシーのメインループでは「ソケットから読み取ったメッセージを他の相手に転送する処理」を繰り返していますので、DEALERソケットからは3つのフレームが出ていく事になります。
ネットワークトラフィックを監視すると、DEALERソケットからREPソケットに向けて3つのフレームが飛び出してくるのを確認できるでしょう。
REPソケットは新しい応答アドレスを含むエンベロープ全体を取り除き、「Hello」というメッセージをアプリケーションに返します。

;Incidentally the REP socket can only deal with one request-reply exchange at a time, which is why if you try to read multiple requests or send multiple replies without sticking to a strict recv-send cycle, it gives an error.

繰り返しになりますが、REPソケットは同時にに1回のリクエスト・応答のやりとりしか行うことが出来ません。
複数のリクエストや応答をいっぺんに送ってしまうと、エラーが発生しますので、送受信の順序を守って1つずつ行なって下さい。

;You should now be able to visualize the return path. When hwserver sends "World" back, the REP socket wraps that with the envelope it saved, and sends a three-frame reply message across the wire to the DEALER socket.

これで、応答経路をイメージできるようになったはずです。
hwserverが「World」というメッセージを返信する時、REPソケットは退避していた、エンベロープを再び付加して3フレームのメッセージをDEALERソケットに対して送信します。

![アドレス付きの応答](images/fig29.eps)

;Now the DEALER reads these three frames, and sends all three out via the ROUTER socket. The ROUTER takes the first frame for the message, which is the ABC identity, and looks up the connection for this. If it finds that, it then pumps the next two frames out onto the wire.

ここで、DEALERは3つのフレームを受信し、全てのフレームはROUTERソケットに渡されます。
ROUTERは最初のメッセージフレームを読み取り、ABCというIDに対応する接続を検索します。接続が見つかったら、残りの2フレームをネットワークに送り出します。

![最小の応答エンベロープ](images/fig30.eps)

;The REQ socket picks this message up, and checks that the first frame is the empty delimiter, which it is. The REQ socket discards that frame and passes "World" to the calling application, which prints it out to the amazement of the younger us looking at ØMQ for the first time.

REQソケットはメッセージを受信し、最初のフレームが空の区切りフレームであることを確認し、これを破棄します。
そして、「World」というメッセーがアプリケーションに渡され、ØMQを始めてみた時の驚きとともに表示されます。

### なにかいい事あるの?(What's This Good For?)
;To be honest, the use cases for strict request-reply or extended request-reply are somewhat limited. For one thing, there's no easy way to recover from common failures like the server crashing due to buggy application code. We'll see more about this in Chapter 4 - Reliable Request-Reply Patterns. However once you grasp the way these four sockets deal with envelopes, and how they talk to each other, you can do very useful things. We saw how ROUTER uses the reply envelope to decide which client REQ socket to route a reply back to. Now let's express this another way:

正直に言うと、素のリクエスト・応答パターンや拡張したリクエスト・応答パターンには幾つかの制限があります。
ひとつ例を挙げると、サーバー側のアプリケーションのバグに起因したクラッシュなどの一般的な障害から回復する簡単な方法がありません。
これは第4章の「信頼性のあるリクエスト・応答パターン」で詳しく解説します。

さておき、4つのソケットがどの様な方法でエンベロープを扱い、お互いに会話するかを理解しておくことは大変有用です。
これまで、ROUTERがどの様に応答エンベロープを利用してクライアントのREQソケットに応答するかを見てきましたので、簡単にまとめておきます。

;* Each time ROUTER gives you a message, it tells you what peer that came from, as an identity.
;* You can use this with a hash table (with the identity as key) to track new peers as they arrive.
;* ROUTER will route messages asynchronously to any peer connected to it, if you prefix the identity as the first frame of the message.

* ROUTERがメッセージを受け取ると、接続元である相手をIDとして記録します。
* 接続相手は、IDをキーとしたハッシュテーブルで保持します。
* ROUTERはメッセージの最初のフレームをIDとして非同期でルーティングします。

;ROUTER sockets don't care about the whole envelope. They don't know anything about the empty delimiter. All they care about is that one identity frame that lets them figure out which connection to send a message to.

ROUTERソケットはエンベロープ全体については関知しません。
例えば区切りフレームについては何も知りません。
メッセージを送信する為の接続先を知るためにIDフレームのみを参照します。

### リクエスト・応答ソケットのまとめ
;Let's recap this:

まとめると、

;* The REQ socket sends, to the network, an empty delimiter frame in front of the message data. REQ sockets are synchronous. REQ sockets always send one request and then wait for one reply. REQ sockets talk to one peer at a time. If you connect a REQ socket to multiple peers, requests are distributed to and replies expected from each peer one turn at a time.

;* The REP socket reads and saves all identity frames up to and including the empty delimiter, then passes the following frame or frames to the caller. REP sockets are synchronous and talk to one peer at a time. If you connect a REP socket to multiple peers, requests are read from peers in fair fashion, and replies are always sent to the same peer that made the last request.

;* The DEALER socket is oblivious to the reply envelope and handles this like any multipart message. DEALER sockets are asynchronous and like PUSH and PULL combined. They distribute sent messages among all connections, and fair-queue received messages from all connections.

;* The ROUTER socket is oblivious to the reply envelope, like DEALER. It creates identities for its connections, and passes these identities to the caller as a first frame in any received message. Conversely, when the caller sends a message, it use the first message frame as an identity to look up the connection to send to. ROUTERS are asynchronous.

* REQソケットはメッセージデータの先頭に空の区切りフレームを付けてネットワークに送信します。REQソケットは同期的に、ひとつのリクエストを送信したら応答が返ってくるまで待つ必要があります。REQソケットが通信できる相手は同時に1つだけです。もし、複数の相手に接続した場合リクエストは分散され、同時に1つの相手からの応答を期待します。

* REPソケットは全てのIDフレームと空の区切りフレームを読み込み、退避します。そして残りのフレームがアプリケーションに渡されます。REPソケットも同期的であり、同時に1つの相手としか通信を行いません。REPソケットに複数の相手が接続してきた場合は接続相手からの要求メッセージを均等に受信し、常に受信した相手に対して応答を返します。

* DEALERソケットは応答エンベロープやマルチパートメッセージ処理に関しては無関心です。DEALERソケットはPUSHソケットとPULLソケットの組み合わせの様に非同期です。メッセージは全ての接続相手に対して分散して送信し、受信時は全ての接続相手から均等にキューイングを行います。

* ROUTERソケットはDEALERソケットと同様に、応答エンベロープに関しては無関心です。このソケットはメッセージを受信すると、接続元を特定するIDを最初のフレームに追加します。逆に、このソケットから送信する際、最初のフレームのIDを参照して送信先を決定します。ROUTERSソケットも非同期です。

## リクエスト・応答の組み合わせ
;We have four request-reply sockets, each with a certain behavior. We've seen how they connect in simple and extended request-reply patterns. But these sockets are building blocks that you can use to solve many problems.

リクエスト・応答ソケットにはそれぞれ異なる振る舞いをする4つのソケットがあり、
これらの簡単な利用方法や、拡張されたリクエスト・応答パターンの利用方法を見てきました。
これらのソケットを活用することで、多くの問題を解決するブロックを構築できるでしょう。

;These are the legal combinations:

正しいソケットの組み合わせは以下の通りです。

* REQからREP
* DEALERからREP
* REQからROUTER
* DEALERからROUTER
* DEALERからDEALER
* ROUTERからROUTER

And these combinations are invalid (and I'll explain why):
そして以下の組み合わせは不正です。(理由は後ほど説明します)

* REQからREQ
* REQからDEALER
* REPからREP
* REPからROUTER

;Here are some tips for remembering the semantics. DEALER is like an asynchronous REQ socket, and ROUTER is like an asynchronous REP socket. Where we use a REQ socket, we can use a DEALER; we just have to read and write the envelope ourselves. Where we use a REP socket, we can stick a ROUTER; we just need to manage the identities ourselves.

ここでは、意味を覚えるためのヒントを幾つか紹介します。
DEALERは非同期になったREQソケットの様なもので、ROUTERはREPソケットの非同期版と言えます。
REQソケットを使う場合のみDEALERソケットを使うことが出来、メッセージのエンベロープを読み書きする必要があります。
REPソケットを利用する場合のみ、ROUTERを配置することが出来、IDを管理する必要があります。

;Think of REQ and DEALER sockets as "clients" and REP and ROUTER sockets as "servers". Mostly, you'll want to bind REP and ROUTER sockets, and connect REQ and DEALER sockets to them. It's not always going to be this simple, but it is a clean and memorable place to start.

REQソケットとDEALERソケット側の事を「クライアント」、REPソケットとROUTERソケット側の事を「サーバー」として見ることができます。多くの場合、REPソケットとROUTERソケットでbindを行うでしょうし、REQソケットとDEALERソケットが接続を行います。
いつもこの様に単純だとは限りませんが、大体こんな風に覚えておけば良いでしょう。

### REQとREPの組み合わせ
;We've already covered a REQ client talking to a REP server but let's take one aspect: the REQ client must initiate the message flow. A REP server cannot talk to a REQ client that hasn't first sent it a request. Technically, it's not even possible, and the API also returns an EFSM error if you try it.

既に私達はREQクライアントがREPサーバーと通信する仕組みについて見てきましたが,
ここでは、ちょっと別の側面を見て行きましょう。
メッセージフローはREQクライアントが開始する必要があります。
REPサーバーまずリクエストを受け取らなければ、REQクライアントに対して通信を行うことは出来ません。
技術的にそれは不可能であり、もしこれをやろうとすると、APIはEFSMエラーを返します。

### DEALERとREPの組み合わせ
;Now, let's replace the REQ client with a DEALER. This gives us an asynchronous client that can talk to multiple REP servers. If we rewrote the "Hello World" client using DEALER, we'd be able to send off any number of "Hello" requests without waiting for replies.

それではREQクライアントをDEALERソケットに置き換えてみましょう。
これは複数のREPサーバーと通信可能な非同期なクライアントを実現できます。
例えば「Hello World」クライアントをDEALERで書き直した場合、応答を待たずに複数の「Hello」リクエストを送信可能です。

;When we use a DEALER to talk to a REP socket, we must accurately emulate the envelope that the REQ socket would have sent, or the REP socket will discard the message as invalid. So, to send a message, we:

DEALERソケットからREPソケットに対して通信行う場合、REQソケットから送信が行われたように正確にエミュレートしする必要があります。
そうしなければREPソケットは不正なメッセージとみなして破棄してしまうでしょう。
すなわち、以下のように送信する必要があります。

;* Send an empty message frame with the MORE flag set; then
;* Send the message body.

* MOREフラグをセットして、空のフレームを送信
* 続いてメッセージ本体を送信

;And when we receive a message, we:

そして受信時は、

;* Receive the first frame and if it's not empty, discard the whole message;
;* Receive the next frame and pass that to the application.

* 受信した最初のフレームが空でなければ、メッセージ全体を破棄します。
* 空フレームに続くフレームをアプリケーションに渡します。

### REQとROUTERの組み合わせ
;In the same way that we can replace REQ with DEALER, we can replace REP with ROUTER. This gives us an asynchronous server that can talk to multiple REQ clients at the same time. If we rewrote the "Hello World" server using ROUTER, we'd be able to process any number of "Hello" requests in parallel. We saw this in the Chapter 2 - Sockets and Patterns mtserver example.

REQソケットをDEALERソケットに置き換えたのと同様に、REPソケットをROUTERソケットに置き換える事が出来ます。
これは複数のREQクライアントに対して同時に通信可能な非同期なサーバーを実現できます。
例えば「Hello World」サーバーをROUTERソケットで書き直した場合、複数の「Hello」リクエストを並行に処理することが可能です。
これは既に第2章の「Sockets and Patterns mtserver」の例で見てきました。

;We can use ROUTER in two distinct ways:

ROUTERソケットは明確に2つの用途で利用できます。

;* As a proxy that switches messages between frontend and backend sockets.
;* As an application that reads the message and acts on it.

* フロントエンドとバックエンドソケットの間でメッセージを中継するプロキシーとして
* メッセージ受信するアプリケーションとして

;In the first case, the ROUTER simply reads all frames, including the artificial identity frame, and passes them on blindly. In the second case the ROUTER must know the format of the reply envelope it's being sent. As the other peer is a REQ socket, the ROUTER gets the identity frame, an empty frame, and then the data frame.

最初のケースではROUTERソケットはIDフレームを含む全てのフレームを受信し、盲目的にメッセージを通過させます。
2番目のケースではROUTERソケットは応答エンベロープの形式を意識する必要があります。
相手がREQソケットだとすると、ROUTERソケットはまずIDフレームと空フレームを受信し、それからデータフレームを受け取ります。

### DEALERとROUTERの組み合わせ
;Now we can switch out both REQ and REP with DEALER and ROUTER to get the most powerful socket combination, which is DEALER talking to ROUTER. It gives us asynchronous clients talking to asynchronous servers, where both sides have full control over the message formats.

そして、REQソケットとREPソケットの組み合わせをDEALERソケットとROUTERソケットという強力な組み合わせに置き換えることが可能です。
これは非同期なクライアントと、非同期なサーバーを実現可能で、両側でメッセージエンべロープの形式を意識する必要があります。

;Because both DEALER and ROUTER can work with arbitrary message formats, if you hope to use these safely, you have to become a little bit of a protocol designer. At the very least you must decide whether you wish to emulate the REQ/REP reply envelope. It depends on whether you actually need to send replies or not.

なぜなら、DEALERソケットとROUTERソケットの両側で自由なメッセージフォーマットを利用できるので、これらを安全に扱いたい場合は少し慎重にプロトコル設計を行う必要があります。
最低限、あなたはREQ/REPソケットの応答エンベロープをエミュレートするかどうかを決める必要があります。
この決定は、応答を必ず返す必要があるかどうかに関わってきます。

### DEALERとDEALERの組み合わせ
;You can swap a REP with a ROUTER, but you can also swap a REP with a DEALER, if the DEALER is talking to one and only one peer.

REPソケットをROUTERソケットに置き換える事が可能ですが、通信相手が1つの場合に限り、REPソケットをDEALERソケットに置き換えることも可能です。

;When you replace a REP with a DEALER, your worker can suddenly go full asynchronous, sending any number of replies back. The cost is that you have to manage the reply envelopes yourself, and get them right, or nothing at all will work. We'll see a worked example later. Let's just say for now that DEALER to DEALER is one of the trickier patterns to get right, and happily it's rare that we need it.

REPソケットをDEALERソケットで置き換えた場合、ワーカーは完全に非同期に応答を返すようになるでしょう。
対価として、応答エンベロープを自分で管理して正しく取得する必要がする必要があります。そうしなければまったく動作しません。
後ほど実際に動作する例を見ていきますが、このDEALERソケットとDEALERソケットの組み合わせはトリッキーなパターンの一つであり、これが必要となるケースは稀でしょう。

### ROUTERとROUTERの組み合わせ
;This sounds perfect for N-to-N connections, but it's the most difficult combination to use. You should avoid it until you are well advanced with ØMQ. We'll see one example it in the Freelance pattern in Chapter 4 - Reliable Request-Reply Patterns, and an alternative DEALER to ROUTER design for peer-to-peer work in Chapter 8 - A Framework for Distributed Computing.

これは完全なN対N接続のように思うかもしれませんが、これは最も扱いにくい組み合わせです。
ØMQを使いこなせる様になるまで、この使い方は避けたほうが無難です。
第4章信頼性のあるリクエスト・応答パターン「」ではこれを利用したフリーランス・パターンをという例を見ていきます。
また、第8章「分散コンピューティング・フレームワーク」ではP2P機能を設計するする為のDEALER対ROUTER通信の代替としてとして紹介します。

### 不正な組み合わせ
;Mostly, trying to connect clients to clients, or servers to servers is a bad idea and won't work. However, rather than give general vague warnings, I'll explain in detail:

クライアントとクライアント、サーバーとサーバーで接続しようとする試みは、ほとんどの場合上手く動作しません。
しかし、ここでは曖昧な警告で終わらせるのではなく具体的に説明しておきます。

;* REQ to REQ: both sides want to start by sending messages to each other, and this could only work if you timed things so that both peers exchanged messages at the same time. It hurts my brain to even think about it.

;* REQ to DEALER: you could in theory do this, but it would break if you added a second REQ because DEALER has no way of sending a reply to the original peer. Thus the REQ socket would get confused, and/or return messages meant for another client.

;* REP to REP: both sides would wait for the other to send the first message.

;* REP to ROUTER: the ROUTER socket can in theory initiate the dialog and send a properly-formatted request, if it knows the REP socket has connected and it knows the identity of that connection. It's messy and adds nothing over DEALER to ROUTER.

* REQとREQの組み合わせ: 両者ともメッセージの送信を開始しようとします。そしてこれが正しく動作するのは、両者がぴったり同時にリクエストを送信した場合のみです。これについて考えると頭痛がします。

* REQとDEALERの組み合わせ: 理論上これを行うことは可能ですが、2つ目のREQを追加した時に破綻します。なぜならDEALERには元々の相手に応答を送信する機能が存在しないからです。従って、REQソケットは混乱してしまい誤ったクライアントにメッセージを返してしまう可能性があります。

* REPとREPの組み合わせ: お互いに最初のメッセージを待ち続けるでしょう。

* REPとROUTERの組み合わせ: 相手がREPソケットだという事が判っている場合、ROUTERソケットは理論上対話を開始することが可能であり、正しい形式のリクエストを送信することが出来ます。それはDEALERとROUTERの組み合わせと比べてややこしいだけで良いことは一つもありません。

;The common thread in this valid versus invalid breakdown is that a ØMQ socket connection is always biased towards one peer that binds to an endpoint, and another that connects to that. Further, that which side binds and which side connects is not arbitrary, but follows natural patterns. The side which we expect to "be there" binds: it'll be a server, a broker, a publisher, a collector. The side that "comes and goes" connects: it'll be clients and workers. Remembering this will help you design better ØMQ architectures.

ØMQの正しいソケットの組み合わせについて一貫して言えることは、常にどちらかがエンドポイントとしてbindし、もう片方が接続を行うという事です。
なお、どちらがbindを行いどちらが接続を行っても構わないのですが、自然なパターンに従うのが良いでしょう。
「存在が確か」である事を期待される側がbindを行い、サーバーやブローカー、パブリッシャーとなるでしょう。一方、「現れたり消えたり」する側が接続を行い、クライアントやワーカーとなるでしょう。
これを覚えておくと、より良いØMQアーキテクチャを設計するのに役立ちます。

## ROUTERソケットの詳細
;Let's look at ROUTER sockets a little closer. We've already seen how they work by routing individual messages to specific connections. I'll explain in more detail how we identify those connections, and what a ROUTER socket does when it can't send a message.

ROUTERソケットについてもう少し詳しく見ていきましょう。
これまでに、個別のメッセージを特定の接続にルーティングする機能について見てきました。
ここでは、コネクションの識別方法についての詳細と、ROUTERが何を行い、どんな時にメッセージを送信できないかについて説明します。

### IDとアドレス
;The identity concept in ØMQ refers specifically to ROUTER sockets and how they identify the connections they have to other sockets. More broadly, identities are used as addresses in the reply envelope. In most cases, the identity is arbitrary and local to the ROUTER socket: it's a lookup key in a hash table. Independently, a peer can have an address that is physical (a network endpoint like "tcp://192.168.55.117:5670") or logical (a UUID or email address or other unique key).

ØMQにおけるIDはROUTERソケットが他のソケットへのコネクションを識別するための概念です。
もっと大ざっぱに言うと、IDは応答エンベロープのアドレスとして利用されます。
多くの場合、このIDはROUTERがハッシュテーブルの検索に利用するための局所的なものです。
[TODO]
ところで、アドレスにはネットワークのエンドポイント「tcp://192.168.55.117:5670」の様な物理的なものとUUID、メールアドレスやユニークなキーの様に論理的なものがあります。

;An application that uses a ROUTER socket to talk to specific peers can convert a logical address to an identity if it has built the necessary hash table. Because ROUTER sockets only announce the identity of a connection (to a specific peer) when that peer sends a message, you can only really reply to a message, not spontaneously talk to a peer.


アプリケーションがROUTERソケットを利用して特定の相手に対して通信を行う際、ハッシュテーブルを構築することで、論理的なアドレスをIDに変換することが出来ます。
なぜなら、ROUTERソケットだけがメッセージを送信する際に接続IDを知ることができるからです。
[TODO]

;This is true even if you flip the rules and make the ROUTER connect to the peer rather than wait for the peer to connect to the ROUTER. However you can force the ROUTER socket to use a logical address in place of its identity. The zmq_setsockopt reference page calls this setting the socket identity. It works as follows:

これとは逆に、ROUTER側から接続を行う場合も同様です。
そして、このIDの代わりに論理的なIDを強制的に利用する事も可能です。
zmq_setsockoptのmanページではこれを「ソケットIDの設定」と呼んでいます。
これは以下の様に動作します。

;* The peer application sets the ZMQ_IDENTITY option of its peer socket (DEALER or REQ) before binding or connecting.
;* Usually the peer then connects to the already-bound ROUTER socket. But the ROUTER can also connect to the peer.
;* At connection time, the peer socket tells the router socket, "please use this identity for this connection".
;* If the peer socket doesn't say that, the router generates its usual arbitrary random identity for the connection.
;* The ROUTER socket now provides this logical address to the application as a prefix identity frame for any messages coming in from that peer.
;* The ROUTER also expects the logical address as the prefix identity frame for any outgoing messages.

* アプリケーションはbindや接続を行う前にソケット(DEALER、もしくはREQ)に対してZMQ_IDENTITYオプションを設定します。
* 通常、bind済みのROUTERソケットに対して接続が行われます。しかし、ROUTERソケットは接続しに行く事も可能です。
* 接続時、接続相手はROUTERソケットに対して「この接続IDを利用してね」と伝えます。
* 接続相手がこれを伝えなかった場合、ROUTER側でランダムな接続IDを生成します。
* ROUTERソケットは受け取ったメッセージに対して論理アドレスを付加します。
* そしてROUTERソケットから出ていくメッセージにはIDフレームが付加されていることを期待します。

;Here is a simple example of two peers that connect to a ROUTER socket, one that imposes a logical address "PEER2":

以下のサンプルコードは、2つのソケットでルーターソケットに対して接続を行い、片方のソケットに「PEER2」という論理アドレスを設定する単純な例です。

~~~ {caption="identity: Identity check in C"}
// Demonstrate request-reply identities

#include "zhelpers.h"

int main (void)
{
   void *context = zmq_ctx_new ();
   void *sink = zmq_socket (context, ZMQ_ROUTER);
   zmq_bind (sink, "inproc://example");

   // First allow 0MQ to set the identity
   void *anonymous = zmq_socket (context, ZMQ_REQ);
   zmq_connect (anonymous, "inproc://example");
   s_send (anonymous, "ROUTER uses a generated UUID");
   s_dump (sink);

   // Then set the identity ourselves
   void *identified = zmq_socket (context, ZMQ_REQ);
   zmq_setsockopt (identified, ZMQ_IDENTITY, "PEER2", 5);
   zmq_connect (identified, "inproc://example");
   s_send (identified, "ROUTER socket uses REQ's socket identity");
   s_dump (sink);

   zmq_close (sink);
   zmq_close (anonymous);
   zmq_close (identified);
   zmq_ctx_destroy (context);
   return 0;
}
~~~

このプログラムは以下の出力を行います。

~~~
----------------------------------------
[005] 006B8B4567
[000]
[026] ROUTER uses a generated UUID
----------------------------------------
[005] PEER2
[000]
[038] ROUTER uses REQ's socket identity
~~~

### ROUTERのエラー処理
;ROUTER sockets do have a somewhat brutal way of dealing with messages they can't send anywhere: they drop them silently. It's an attitude that makes sense in working code, but it makes debugging hard. The "send identity as first frame" approach is tricky enough that we often get this wrong when we're learning, and the ROUTER's stony silence when we mess up isn't very constructive.

ROUTERソケットはメッセージを送信できない場合に黙って捨てるという荒っぽい挙動を行います。
これは実際のコードでは合理的な動作ですがデバッグが難しくなるのが難点です。

この最初のフレームにIDを含めて送信する方式は、注意しなければ誤った結果が得られたり、ROUTERは黙ってメッセージを捨てるので混乱してしまうかもしれません。

;Since ØMQ v3.2 there's a socket option you can set to catch this error: ZMQ_ROUTER_MANDATORY. Set that on the ROUTER socket and then when you provide an unroutable identity on a send call, the socket will signal an EHOSTUNREACH error.

ØMQ v3.2以降、このエラーを検知できるZMQ_ROUTER_MANDATORYソケットオプションが追加されました。
ROUTERソケットにこれを設定すると、ルーティング出来ないIDに対して送信した場合にソケットがEHOSTUNREACHエラーを通知します。

## 負荷分散パターン
;Now let's look at some code. We'll see how to connect a ROUTER socket to a REQ socket, and then to a DEALER socket. These two examples follow the same logic, which is a load balancing pattern. This pattern is our first exposure to using the ROUTER socket for deliberate routing, rather than simply acting as a reply channel.

それではコードを見て行きましょう。
これからREQソケットやDEALERソケットでROUTERソケットに接続する方法を見ていきます。
この2つのパターンは同じく負荷分散パターンというロジックに従っています。
単純な応答を行うのではなく、意図的にルーティングを行う例としてこのパターンは初めて紹介することになります。

;The load balancing pattern is very common and we'll see it several times in this book. It solves the main problem with simple round robin routing (as PUSH and DEALER offer) which is that round robin becomes inefficient if tasks do not all roughly take the same time.

負荷分散パターンは極めて一般的であり、この本の中で何度か出てくるでしょう。
PUSHとDEALERソケットとは異なり、負荷分散は単純なラウンドロビンを利用しますが、ラウンドロビンはタスクの処理時間が均等でない場合に非効率になる事があります。

;It's the post office analogy. If you have one queue per counter, and you have some people buying stamps (a fast, simple transaction), and some people opening new accounts (a very slow transaction), then you will find stamp buyers getting unfairly stuck in queues. Just as in a post office, if your messaging architecture is unfair, people will get annoyed.

郵便局で例えてみましょう。、
郵便局の同じ窓口に切手を買いに来た人々(速いトランザクション)と新規口座を開設しに来た人々(非常に遅いトランザクション)が並んでいるとしましょう。
そうすると、切手を買いに来た人が不当に待たされてしまうことに気がつくでしょう。
あなたのメッセージングアーキテクチャがこの様な郵便局と同じだった場合、人々はイライラしてしまいます。

;The solution in the post office is to create a single queue so that even if one or two counters get stuck with slow work, other counters will continue to serve clients on a first-come, first-serve basis.

この郵便局の問題の解決方法は、行列が混雑してきた際に、遅い手続きの窓口を別に開設し、速い手続きの窓口は引き続き先着順で処理する事です。

;One reason PUSH and DEALER use the simplistic approach is sheer performance. If you arrive in any major US airport, you'll find long queues of people waiting at immigration. The border patrol officials will send people in advance to queue up at each counter, rather than using a single queue. Having people walk fifty yards in advance saves a minute or two per passenger. And because every passport check takes roughly the same time, it's more or less fair. This is the strategy for PUSH and DEALER: send work loads ahead of time so that there is less travel distance.

PUSHとDEALERソケットがこの様な単純な方式を利用するのは単にパフォーマンスが理由です。
米国の主要な空港に到着すると、入国管理の所で長い行列をが出来ていることがよくあるでしょう。
警備の人は人々をあらかじめ1つではなく複数に分けて行列を作ります。
人々は1,2分程度時間をかけて50ヤードほどの行列を歩きます。
これは公平な方法です。なぜなら全てのパスポートチェックは大体同じ時間で完了するからです。
この様に前もってキューを分ける事で、移動距離を短くすることがPUSHとDEALERソケットの戦略です。

;This is a recurring theme with ØMQ: the world's problems are diverse and you can benefit from solving different problems each in the right way. The airport isn't the post office and one size fits no one, really well.

これは、ØMで繰り返し議論されてきたテーマです。
現実世界の問題は多様化しており、異なる問題にはそれぞれ正しい解決方法があります。
空港は郵便局と異なるように、問題の規模はそれぞれ異なるのです。

;Let's return to the scenario of a worker (DEALER or REQ) connected to a broker (ROUTER). The broker has to know when the worker is ready, and keep a list of workers so that it can take the least recently used worker each time.

それでは、ブローカー(ROUTERソケット)に対してワーカー(DEALERやREQソケット)が接続する例に戻りましょう。
ブローカーはワーカーの準備が完了したことを知っていて、ワーカーの一覧を保持する必要があります。

;The solution is really simple, in fact: workers send a "ready" message when they start, and after they finish each task. The broker reads these messages one-by-one. Each time it reads a message, it is from the last used worker. And because we're using a ROUTER socket, we get an identity that we can then use to send a task back to the worker.

これを行う方法は簡単です。
ワーカーは起動時に「準備完了」メッセージを送信し、その後仕事を行います。
ブローカーは最も古いものから順にメッセージを1つずつ読み込んでいきます。
そして、今回はROUTERソケットを利用しているので、ワーカーに返信するためのIDを取得しています。

;It's a twist on request-reply because the task is sent with the reply, and any response for the task is sent as a new request. The following code examples should make it clearer.

これはリクエストに対して応答を返していることから、リクエスト・応答パターンの応用と言えます。
これらを理解する為のサンプルコードを示します。

### ROUTERブローカーとREQワーカー

;Here is an example of the load balancing pattern using a ROUTER broker talking to a set of REQ workers:

これはROUTERブローカーを利用してREQワーカー群と通信を行う負荷分散パターンのサンプルコードです。

~~~ {caption="rtreq: ROUTER-to-REQ in C"}
// ROUTER-to-REQ example

#include "zhelpers.h"
#include <pthread.h>
#define NBR_WORKERS 10

static void *
worker_task (void *args)
{
    void *context = zmq_ctx_new ();
    void *worker = zmq_socket (context, ZMQ_REQ);
    s_set_id (worker); // Set a printable identity
    zmq_connect (worker, "tcp://localhost:5671");

    int total = 0;
    while (1) {
        // Tell the broker we're ready for work
        s_send (worker, "Hi Boss");

        // Get workload from broker, until finished
        char *workload = s_recv (worker);
        int finished = (strcmp (workload, "Fired!") == 0);
        free (workload);
        if (finished) {
            printf ("Completed: %d tasks\n", total);
            break;
        }
        total++;

        // Do some random work
        s_sleep (randof (500) + 1);
    }
    zmq_close (worker);
    zmq_ctx_destroy (context);
    return NULL;
}

// While this example runs in a single process, that is only to make
// it easier to start and stop the example. Each thread has its own
// context and conceptually acts as a separate process.

int main (void)
{
    void *context = zmq_ctx_new ();
    void *broker = zmq_socket (context, ZMQ_ROUTER);

    zmq_bind (broker, "tcp://*:5671");
    srandom ((unsigned) time (NULL));

    int worker_nbr;
    for (worker_nbr = 0; worker_nbr < NBR_WORKERS; worker_nbr++) {
        pthread_t worker;
        pthread_create (&worker, NULL, worker_task, NULL);
    }
    // Run for five seconds and then tell workers to end
    int64_t end_time = s_clock () + 5000;
    int workers_fired = 0;
    while (1) {
        // Next message gives us least recently used worker
        char *identity = s_recv (broker);
        s_sendmore (broker, identity);
        free (identity);
        free (s_recv (broker)); // Envelope delimiter
        free (s_recv (broker)); // Response from worker
        s_sendmore (broker, "");

        // Encourage workers until it's time to fire them
        if (s_clock () < end_time)
            s_send (broker, "Work harder");
        else {
            s_send (broker, "Fired!");
        if (++workers_fired == NBR_WORKERS)
            break;
        }
    }
    zmq_close (broker);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

;The example runs for five seconds and then each worker prints how many tasks they handled. If the routing worked, we'd expect a fair distribution of work:

このサンプルコードを実行して5秒程度待つと、各ワーカーが処理したタスクの数を出力します。
ルーティングが機能していれば、タスクは均等に分散されているはずです。

~~~
Completed: 20 tasks
Completed: 18 tasks
Completed: 21 tasks
Completed: 23 tasks
Completed: 19 tasks
Completed: 21 tasks
Completed: 17 tasks
Completed: 17 tasks
Completed: 25 tasks
Completed: 19 tasks
~~~

;To talk to the workers in this example, we have to create a REQ-friendly envelope consisting of an identity plus an empty envelope delimiter frame.

この例では、REQソケットと通信を行うために、
IDフレームと空のエンベロープフレームを加えたメッセージを作成する必要があります。

![REQソケットと通信するためのルーティングエンベロープ](images/fig31.eps)

### ROUTERブローカーとDEALERワーカー
;Anywhere you can use REQ, you can use DEALER. There are two specific differences:

REQソケットの代わりにDEALERソケットを利用することも可能です。
これらには2つの明確な違いあがあります。

;* The REQ socket always sends an empty delimiter frame before any data frames; the DEALER does not.
;* The REQ socket will send only one message before it receives a reply; the DEALER is fully asynchronous.

* REQソケットは常にデータフレームの前に空の区切りフレームを付けて送信していましたがDEALERソケットはこれを行いません。
* REQソケットは受信を行うまでに1つのメッセージしか送信できません。しかしDEALER完全に非同期ですのでこれが可能です。

;The synchronous versus asynchronous behavior has no effect on our example because we're doing strict request-reply. It is more relevant when we address recovering from failures, which we'll come to in Chapter 4 - Reliable Request-Reply Patterns.

同期から非同期に切り替える場合でも、リクエスト・応答パターンという事に変わりありませんのでサンプルコードに大きな影響を与えません。
この組み合わせはエラーからの復旧に関連していますので、後の第4章「信頼性のあるリクエスト・応答パターン」でも出てきます。

;Now let's look at exactly the same example but with the REQ socket replaced by a DEALER socket:

それでは、REQソケットをDEALERソケットに置き換えたまったく同じ動作を行うサンプルコードを見てみましょう。

~~~ {caption="rtdealer: ROUTER-to-DEALER in C"}
// ROUTER-to-DEALER example

#include "zhelpers.h"
#include <pthread.h>
#define NBR_WORKERS 10

static void *
worker_task (void *args)
{
    void *context = zmq_ctx_new ();
    void *worker = zmq_socket (context, ZMQ_DEALER);
    s_set_id (worker); // Set a printable identity
    zmq_connect (worker, "tcp://localhost:5671");

    int total = 0;
    while (1) {
        // Tell the broker we're ready for work
        s_sendmore (worker, "");
        s_send (worker, "Hi Boss");

        // Get workload from broker, until finished
        free (s_recv (worker)); // Envelope delimiter
        char *workload = s_recv (worker);
        int finished = (strcmp (workload, "Fired!") == 0);
        free (workload);
        if (finished) {
            printf ("Completed: %d tasks\n", total);
            break;
        }
        total++;

        // Do some random work
        s_sleep (randof (500) + 1);
    }
    zmq_close (worker);
    zmq_ctx_destroy (context);
    return NULL;
}

// While this example runs in a single process, that is just to make
// it easier to start and stop the example. Each thread has its own
// context and conceptually acts as a separate process.

int main (void)
{
    void *context = zmq_ctx_new ();
    void *broker = zmq_socket (context, ZMQ_ROUTER);

    zmq_bind (broker, "tcp://*:5671");
    srandom ((unsigned) time (NULL));

    int worker_nbr;
    for (worker_nbr = 0; worker_nbr < NBR_WORKERS; worker_nbr++) {
        pthread_t worker;
        pthread_create (&worker, NULL, worker_task, NULL);
    }
    // Run for five seconds and then tell workers to end
    int64_t end_time = s_clock () + 5000;
    int workers_fired = 0;
    while (1) {
        // Next message gives us least recently used worker
        char *identity = s_recv (broker);
        s_sendmore (broker, identity);
        free (identity);
        free (s_recv (broker)); // Envelope delimiter
        free (s_recv (broker)); // Response from worker
        s_sendmore (broker, "");

        // Encourage workers until it's time to fire them
        if (s_clock () < end_time)
            s_send (broker, "Work harder");
        else {
            s_send (broker, "Fired!");
        if (++workers_fired == NBR_WORKERS)
            break;
        }
    }
    zmq_close (broker);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

;The code is almost identical except that the worker uses a DEALER socket, and reads and writes that empty frame before the data frame. This is the approach I use when I want to keep compatibility with REQ workers.

このコードはワーカーがDEALERソケットを利用して、データフレームの前に空フレームを付けて送信していることを除いて殆ど同じです。
この方法はREQワーカーと互換性を保ちたい場合に役立ちます。

;However, remember the reason for that empty delimiter frame: it's to allow multihop extended requests that terminate in a REP socket, which uses that delimiter to split off the reply envelope so it can hand the data frames to its application.

一方で、空の区切りフレームの存在意義を忘れないで下さい。
それは終端にあるREPソケットが応答エンベロープとデータフレームを区別するためのものです。

;If we never need to pass the message along to a REP socket, we can simply drop the empty delimiter frame at both sides, which makes things simpler. This is usually the design I use for pure DEALER to ROUTER protocols.

もし、メッセージがREPソケットを経由しないのであれば、両側でこの区切り文字を省略する事が可能で、こうする事でより単純になります。
これは純粋なDEALERとROUTERプロトコルを利用したい場合に一般的な設計です。

### 負荷分散メッセージブローカー
;The previous example is half-complete. It can manage a set of workers with dummy requests and replies, but it has no way to talk to clients. If we add a second frontend ROUTER socket that accepts client requests, and turn our example into a proxy that can switch messages from frontend to backend, we get a useful and reusable tiny load balancing message broker.

前回のサンプルコードは複数のワーカーを管理し、擬似的なリクエストと応答を行うことが出来ましたが、これだけでは十分で無い場合があります。
ワーカーからクライアントに対して問い合わせを行うことが出来ないからです。
2つ目のフロントエンドROUTERソケットを追加し、これでクライアントからのリクエストを受け付け、フロントエンドからバックエンドにメッセージを転送するプロキシーを用意します。
こうすることで、便利で再利用可能な負荷分散メッセージブローカーを作成することが出来ます。

![負荷分散ブローカー](images/fig32.eps)

;This broker does the following:

このブローカーは以下のように動作します。

;* Accepts connections from a set of clients.
;* Accepts connections from a set of workers.
;* Accepts requests from clients and holds these in a single queue.
;* Sends these requests to workers using the load balancing pattern.
;* Receives replies back from workers.
;* Sends these replies back to the original requesting client.

* クライアントからの接続を受け付けます。
* ワーカーからの接続を受け付けます。
* クライアントからのリクエストは単一のキューで保持します。
* これらリクエストは負荷分散パターンを利用してワーカーに送信します。
* ブローカーはワーカーからの応答を受け取ります。
* リクエストを行ったクライアントに応答を返します。

;The broker code is fairly long, but worth understanding:

このサンプルコードはそこそこ長いですが、理解する価値はあるでしょう。

~~~ {caption="lbbroker: Load balancing broker in C"}
// Load-balancing broker
// Clients and workers are shown here in-process

#include "zhelpers.h"
#include <pthread.h>
#define NBR_CLIENTS 10
#define NBR_WORKERS 3

// Dequeue operation for queue implemented as array of anything
#define DEQUEUE(q) memmove (&(q)[0], &(q)[1], sizeof (q) - sizeof (q [0]))

// Basic request-reply client using REQ socket
// Because s_send and s_recv can't handle 0MQ binary identities, we
// set a printable text identity to allow routing.
//
static void *
client_task (void *args)
{
    void *context = zmq_ctx_new ();
    void *client = zmq_socket (context, ZMQ_REQ);
    s_set_id (client); // Set a printable identity
    zmq_connect (client, "ipc://frontend.ipc");

    // Send request, get reply
    s_send (client, "HELLO");
    char *reply = s_recv (client);
    printf ("Client: %s\n", reply);
    free (reply);
    zmq_close (client);
    zmq_ctx_destroy (context);
    return NULL;
}

// While this example runs in a single process, that is just to make
// it easier to start and stop the example. Each thread has its own
// context and conceptually acts as a separate process.
// This is the worker task, using a REQ socket to do load-balancing.
// Because s_send and s_recv can't handle 0MQ binary identities, we
// set a printable text identity to allow routing.



static void *
worker_task (void *args)
{
    void *context = zmq_ctx_new ();
    void *worker = zmq_socket (context, ZMQ_REQ);
    s_set_id (worker); // Set a printable identity
    zmq_connect (worker, "ipc://backend.ipc");

    // Tell broker we're ready for work
    s_send (worker, "READY");

    while (1) {
        // Read and save all frames until we get an empty frame
        // In this example there is only 1, but there could be more
        char *identity = s_recv (worker);
        char *empty = s_recv (worker);
        assert (*empty == 0);
        free (empty);

        // Get request, send reply
        char *request = s_recv (worker);
        printf ("Worker: %s\n", request);
        free (request);

        s_sendmore (worker, identity);
        s_sendmore (worker, "");
        s_send (worker, "OK");
        free (identity);
    }
    zmq_close (worker);
    zmq_ctx_destroy (context);
    return NULL;
}

// This is the main task. It starts the clients and workers, and then
// routes requests between the two layers. Workers signal READY when
// they start; after that we treat them as ready when they reply with
// a response back to a client. The load-balancing data structure is
// just a queue of next available workers.

int main (void)
{
    // Prepare our context and sockets
    void *context = zmq_ctx_new ();
    void *frontend = zmq_socket (context, ZMQ_ROUTER);
    void *backend = zmq_socket (context, ZMQ_ROUTER);
    zmq_bind (frontend, "ipc://frontend.ipc");
    zmq_bind (backend, "ipc://backend.ipc");

    int client_nbr;
    for (client_nbr = 0; client_nbr < NBR_CLIENTS; client_nbr++) {
        pthread_t client;
        pthread_create (&client, NULL, client_task, NULL);
    }
    int worker_nbr;
    for (worker_nbr = 0; worker_nbr < NBR_WORKERS; worker_nbr++) {
        pthread_t worker;
        pthread_create (&worker, NULL, worker_task, NULL);
    }
    // Here is the main loop for the least-recently-used queue. It has two
    // sockets; a frontend for clients and a backend for workers. It polls
    // the backend in all cases, and polls the frontend only when there are
    // one or more workers ready. This is a neat way to use 0MQ's own queues
    // to hold messages we're not ready to process yet. When we get a client
    // reply, we pop the next available worker and send the request to it,
    // including the originating client identity. When a worker replies, we
    // requeue that worker and forward the reply to the original client
    // using the reply envelope.

    // Queue of available workers
    int available_workers = 0;
    char *worker_queue [10];

    while (1) {
        zmq_pollitem_t items [] = {
            { backend, 0, ZMQ_POLLIN, 0 },
            { frontend, 0, ZMQ_POLLIN, 0 }
        };
        // Poll frontend only if we have available workers
        int rc = zmq_poll (items, available_workers ? 2 : 1, -1);
        if (rc == -1)
            break; // Interrupted

        // Handle worker activity on backend
        if (items [0].revents & ZMQ_POLLIN) {
            // Queue worker identity for load-balancing
            char *worker_id = s_recv (backend);
            assert (available_workers < NBR_WORKERS);
            worker_queue [available_workers++] = worker_id;

            // Second frame is empty
            char *empty = s_recv (backend);
            assert (empty [0] == 0);
            free (empty);

            // Third frame is READY or else a client reply identity
            char *client_id = s_recv (backend);

            // If client reply, send rest back to frontend
            if (strcmp (client_id, "READY") != 0) {
                empty = s_recv (backend);
                assert (empty [0] == 0);
                free (empty);
                char *reply = s_recv (backend);
                s_sendmore (frontend, client_id);
                s_sendmore (frontend, "");
                s_send (frontend, reply);
                free (reply);
                if (--client_nbr == 0)
                    break; // Exit after N messages
                }
                free (client_id);
            }
            // Here is how we handle a client request:

            if (items [1].revents & ZMQ_POLLIN) {
            // Now get next client request, route to last-used worker
            // Client request is [identity][empty][request]
            char *client_id = s_recv (frontend);
            char *empty = s_recv (frontend);
            assert (empty [0] == 0);
            free (empty);
            char *request = s_recv (frontend);

            s_sendmore (backend, worker_queue [0]);
            s_sendmore (backend, "");
            s_sendmore (backend, client_id);
            s_sendmore (backend, "");
            s_send (backend, request);

            free (client_id);
            free (request);

            // Dequeue and drop the next worker identity
            free (worker_queue [0]);
            DEQUEUE (worker_queue);
            available_workers--;
        }
    }
    zmq_close (frontend);
    zmq_close (backend);
    zmq_ctx_destroy (context);
    return 0;
}
~~~

;The difficult part of this program is (a) the envelopes that each socket reads and writes, and (b) the load balancing algorithm. We'll take these in turn, starting with the message envelope formats.

このプログラムの難しい所は、(a) 各ソケットでエンベロープを読み書きを行なっている事と、(b) 負荷分散アルゴリズムです。
まずはエンベロープのフォーマットから説明します。

;Let's walk through a full request-reply chain from client to worker and back. In this code we set the identity of client and worker sockets to make it easier to trace the message frames. In reality, we'd allow the ROUTER sockets to invent identities for connections. Let's assume the client's identity is "CLIENT" and the worker's identity is "WORKER". The client application sends a single frame containing "Hello".

それでは、クライアントがリクエストを行い、ワーカーが応答を返す流れを見て行きましょう。
このコードでは、メッセージフレームを追跡し易くする為にクライアントとワーカーのIDを設定しています。
実際にはROUTERソケットが接続IDを割り振ることも出来るでしょう。
ここでは、クライアントのIDを「CLIENT」、ワーカーのIDを「WORKER」だと仮定しましょう。
まず、クライアント側のアプリケーションが「Hello」という単一のメッセージを送信します。

![クライアントが送信するメッセージ](images/fig33.eps)

;Because the REQ socket adds its empty delimiter frame and the ROUTER socket adds its connection identity, the proxy reads off the frontend ROUTER socket the client address, empty delimiter frame, and the data part.

REQソケットが空の区切りフレームを追加し、ルーターソケットが接続IDを追加するので、ブローカーはこのアドレスと区切りフレーム、データフレームを読み込みます。

![フロントエンドで受け取るメッセージ](images/fig34.eps)

;The broker sends this to the worker, prefixed by the address of the chosen worker, plus an additional empty part to keep the REQ at the other end happy.

ブローカーはこのメッセージに送信先に選んだワーカーのアドレスと、区切りフレームを先頭に追加てワーカーに送信します。

![バックエンドに届いたメッセージ](images/fig35.eps)

;This complex envelope stack gets chewed up first by the backend ROUTER socket, which removes the first frame. Then the REQ socket in the worker removes the empty part, and provides the rest to the worker application.

この積み重なった複雑なエンベロープは、まずバックエンドのROUTERソケットで最初のフレームが取り除かれます。
次にワーカー側のREQソケットで空の区切りフレームが取り除かれ、残りがワーカー側のアプリケーションに渡ります。

![ワーカーに到達したメッセージ](images/fig36.eps)

;The worker has to save the envelope (which is all the parts up to and including the empty message frame) and then it can do what's needed with the data part. Note that a REP socket would do this automatically, but we're using the REQ-ROUTER pattern so that we can get proper load balancing.

ワーカーが必要とするのはデータ部ですが、区切りフレームを含むエンベロープ全体を保持しておく必要があります。
ここでは、REQ-ROUTERパターンを利用して負荷分散を行なっているので、REPソケットがこれを自動的に行うことに注意して下さい。

;On the return path, the messages are the same as when they come in, i.e., the backend socket gives the broker a message in five parts, and the broker sends the frontend socket a message in three parts, and the client gets a message in one part.

帰りの経路は来た時と同じです。
すなわち、ブローカーのバックエンドソケットで5つのフレームになり、ブローカーのフロントエンドは3つのフレームが送信されます。そしてクライアントは一つのデータフレームが渡されます。

;Now let's look at the load balancing algorithm. It requires that both clients and workers use REQ sockets, and that workers correctly store and replay the envelope on messages they get. The algorithm is:

それでは負荷分散アルゴリズムを見て行きましょう。
クライアントとワーカーでREQソケットを利用する必要があり、
ワーカーは、受け取ったエンベロープを正しく保持して応答する必要があります。
このアルゴリズムは、

;* Create a pollset that always polls the backend, and polls the frontend only if there are one or more workers available.
;* Poll for activity with infinite timeout.
;* If there is activity on the backend, we either have a "ready" message or a reply for a client. In either case, we store the worker address (the first part) on our worker queue, and if the rest is a client reply, we send it back to that client via the frontend.
;* If there is activity on the frontend, we take the client request, pop the next worker (which is the last used), and send the request to the backend. This means sending the worker address, empty part, and then the three parts of the client request.

* zmq_pollitem_t構造体の配列を作成してバックエンドを常にポーリングします。そして1つ以上ワーカーが存在する場合のみ、フロントエンドをポーリングします。
* ポーリングのタイムアウトは設定しません。
* バックエンドにワーカーからメッセージが送られて来た場合「READY」というメッセージかクライアントへの応答を受け取る可能性があります。どちらの場合でも最初のフレームはワーカーのアドレスですのでワーカーキューに格納します。残りの部分があればフロントエンドソケットを経由してクライアントに応答します。
* フロントエンドにメッセージが送られてきた場合、最後に利用されたワーカーを選択し、リクエストをバックエンドに送信します。この時、ワーカーのアドレス、区切りフレーム、データフレームという3つのフレームを送信します。

;You should now see that you can reuse and extend the load balancing algorithm with variations based on the information the worker provides in its initial "ready" message. For example, workers might start up and do a performance self test, then tell the broker how fast they are. The broker can then choose the fastest available worker rather than the oldest.

これまでの情報を元にして様々な負荷分散アルゴリズムに拡張できることに気がついたと思います。
例えば、ワーカーが起動した後に自分自身でパフォーマンステストを走らせると、ブローカはどのワーカーが一番早いか知ることが出来ます。
こうすることでブローカは最も速いワーカーを選択することが可能です。

## ØMQの高級API

;We're going to push request-reply onto the stack and open a different area, which is the ØMQ API itself. There's a reason for this detour: as we write more complex examples, the low-level ØMQ API starts to look increasingly clumsy. Look at the core of the worker thread from our load balancing broker:

ここでリクエスト・応答パターンの話題から外れ、ØMQ API自身の話になりますがこれには理由があります。
このまま低レベルなØMQを使ってもっと複雑なサンプルコードを書くと可読性が低下してしまうからです。
先ほどの負荷分散ブローカーのワーカースレッドの主要な処理を見て下さい。

~~~
while (true) {
    // Get one address frame and empty delimiter
    char *address = s_recv (worker);
    char *empty = s_recv (worker);
    assert (*empty == 0);
    free (empty);

    // Get request, send reply
    char *request = s_recv (worker);
    printf ("Worker: %s\n", request);
    free (request);

    s_sendmore (worker, address);
    s_sendmore (worker, "");
    s_send (worker, "OK");
    free (address);
}
~~~

}

;That code isn't even reusable because it can only handle one reply address in the envelope, and it already does some wrapping around the ØMQ API. If we used the libzmq simple message API this is what we'd have to write:

このコードはたった1つの応答アドレスしか読み取っていないので、再利用可能ではありません。
そして、既にØMQ APIのヘルパー関数を利用していますが、純粋なlibzmqのAPIを利用する場合は以下のように書く必要があるでしょう。

~~~
while (true) {
    // Get one address frame and empty delimiter
    char address [255];
    int address_size = zmq_recv (worker, address, 255, 0);
    if (address_size == -1)
        break;

    char empty [1];
    int empty_size = zmq_recv (worker, empty, 1, 0);
    zmq_recv (worker, &empty, 0);
    assert (empty_size <= 0);
    if (empty_size == -1)
        break;

    // Get request, send reply
    char request [256];
    int request_size = zmq_recv (worker, request, 255, 0);
    if (request_size == -1)
        return NULL;
    request [request_size] = 0;
    printf ("Worker: %s\n", request);

    zmq_send (worker, address, address_size, ZMQ_SNDMORE);
    zmq_send (worker, empty, 0, ZMQ_SNDMORE);
    zmq_send (worker, "OK", 2, 0);
}
~~~

;And when code is too long to write quickly, it's also too long to understand. Up until now, I've stuck to the native API because, as ØMQ users, we need to know that intimately. But when it gets in our way, we have to treat it as a problem to solve.

そしてこのコードは長すぎるため、理解するのに時間が掛かってしまいます。
これまではØMQに慣れるためにあえて低レベルなAPIを利用してきましたが、そろそろその必要もなくなって来ました。

;We can't of course just change the ØMQ API, which is a documented public contract on which thousands of people agree and depend. Instead, we construct a higher-level API on top based on our experience so far, and most specifically, our experience from writing more complex request-reply patterns.

もちろん、既に多くの人々に周知されているØMQ APIを私達が勝手に変更することは出来ません。
その代わりに私達の経験に基づいて高級APIを用意しています。
特にこれはより複雑なリクエスト・応答パターンを書くために役立ちます。

;What we want is an API that lets us receive and send an entire message in one shot, including the reply envelope with any number of reply addresses. One that lets us do what we want with the absolute least lines of code.

私達が欲しいのは複数の応答エンベロープを含むメッセージを一発で送受信するためのAPIです。
これがあれば、やりたいことを最小のコードで記述することが出来ます。

;Making a good message API is fairly difficult. We have a problem of terminology: ØMQ uses "message" to describe both multipart messages, and individual message frames. We have a problem of expectations: sometimes it's natural to see message content as printable string data, sometimes as binary blobs. And we have technical challenges, especially if we want to avoid copying data around too much.

良質なメッセージAPIを設計するのはとても難しいことです。
まず私達は用語に関する問題を抱えています。
「メッセージ」という用語はマルチパートメッセージを表すこともあるし個別のメッセージフレームを表す場合もあります。
期待するデータ種別が異なるという問題があります。
メッセージは大抵の場合印字可能な文字列でしょうが、バイナリデータでる場合もあります。
そして、技術的な挑戦として、巨大なデータをコピーせずに送信したい場合があります。

;The challenge of making a good API affects all languages, though my specific use case is C. Whatever language you use, think about how you could contribute to your language binding to make it as good (or better) than the C binding I'm going to describe.

私の場合はC言語ですが、良質なAPIを設計するための努力は全ての言語に影響を与えます。
あなたがどのプログラミング言語を利用するにしても、より良い言語バインディングを作れるように考えています。

### 高級APIの機能
;My solution is to use three fairly natural and obvious concepts: string (already the basis for our s_send and s_recv) helpers, frame (a message frame), and message (a list of one or more frames). Here is the worker code, rewritten onto an API using these concepts:

高級APIでは、3つの解かりやすい概念を利用します。
文字列ヘルパー(既に出てきたs_sendやs_recvの様なもの)、フレーム(メッセージフレーム)、そしてメッセージ(1つ以上のフレームで構成される)です。
これらの概念を利用してワーカーのコードを書き直してみます。

~~~
while (true) {
    zmsg_t *msg = zmsg_recv (worker);
    zframe_reset (zmsg_last (msg), "OK", 2);
    zmsg_send (&msg, worker);
}
~~~

;Cutting the amount of code we need to read and write complex messages is great: the results are easy to read and understand. Let's continue this process for other aspects of working with ØMQ. Here's a wish list of things I'd like in a higher-level API, based on my experience with ØMQ so far:

素晴らしいことに、複雑なメッセージを読み書きする為に必要なコードを削減することが出来ました。
これでかなりコードが読み易くなったでしょう。
今後ØMQの他の機能についてはこんな風に説明します。

以下は私の経験を元に設計した高級APIの要件リストです。

;* Automatic handling of sockets. I find it cumbersome to have to close sockets manually, and to have to explicitly define the linger timeout in some (but not all) cases. It'd be great to have a way to close sockets automatically when I close the context.
;* Portable thread management. Every nontrivial ØMQ application uses threads, but POSIX threads aren't portable. So a decent high-level API should hide this under a portable layer.
;* Piping from parent to child threads. It's a recurrent problem: how to signal between parent and child threads. Our API should provide a ØMQ message pipe (using PAIR sockets and inproc automatically.
;* Portable clocks. Even getting the time to a millisecond resolution, or sleeping for some milliseconds, is not portable. Realistic ØMQ applications need portable clocks, so our API should provide them.
;* A reactor to replace zmq_poll(). The poll loop is simple, but clumsy. Writing a lot of these, we end up doing the same work over and over: calculating timers, and calling code when sockets are ready. A simple reactor with socket readers and timers would save a lot of repeated work.
;* Proper handling of Ctrl-C. We already saw how to catch an interrupt. It would be useful if this happened in all applications.

* ソケットの自動処理。私は手動でソケットを閉じたり、明示的にlingerのタイムアウトを設定するのが面倒になりました。ソケットはコンテキストをクローズする時に自動的にクローズしてくれるのが望ましいでしょう。
* 移植性のあるスレッド管理。多くのØMQアプリケーションはスレッドを利用しますが、POSIXスレッドには移植性がありません。ですので高級APIでこの移植レイヤを隠蔽出来るのが望ましいです。
* 親スレッドから子スレッドへのパイプ接続。どの様にして親スレッドと子スレッド同士で通知を行うかという問題は度々発生します。高レベルAPIはPAIRソケットとプロセス内通信を利用するメッセージパイプを提供します。
* 移植性のある時刻の取得方法。既におおよそミリ秒の精度で時刻を取得する方法はありますが移植性がありません。実際のアプリケーションでは移植性のあるAPIが求められます。
* リアクターパターンによるzmq_poll()の置き換え。pollループは単純ですがやや不格好です。大抵の場合、タイマーを設定して、ソケットから読み出すという単純なコードになりがちです。単純なリアクターパターンを導入して余計なな繰り返し作業を削減します。
* Ctrl-Cを適切に処理する。既に割り込みを処理する方法を見てきましたが、これは全てのアプリケーションで必要とされる処理です。

### CZMQ高級API
;Turning this wish list into reality for the C language gives us CZMQ, a ØMQ language binding for C. This high-level binding, in fact, developed out of earlier versions of the examples. It combines nicer semantics for working with ØMQ with some portability layers, and (importantly for C, but less for other languages) containers like hashes and lists. CZMQ also uses an elegant object model that leads to frankly lovely code.

CZMQはこのような要件リストをC言語で実現した高級な言語バインディングです。
これによって、より良い記述と移植性の高いより良い記述が可能になります。
また、C言語に限り、ハッシュやリストなどのコンテナを提供します。
CZMQはソースコードを親しみやすくする、エレガントなオブジェクトモデルを導入しています。

;Here is the load balancing broker rewritten to use a higher-level API (CZMQ for the C case):

以下は、負荷分散ブローカーをC言語の高級API(CZMQ)で書き直したものです。

~~~ {caption="lbbroker2: Load balancing broker using high-level API in C"}
// Load-balancing broker
// Demonstrates use of the CZMQ API

#include "czmq.h"

#define NBR_CLIENTS 10
#define NBR_WORKERS 3
#define WORKER_READY "\001" // Signals worker is ready

// Basic request-reply client using REQ socket
//
static void *
client_task (void *args)
{
    zctx_t *ctx = zctx_new ();
    void *client = zsocket_new (ctx, ZMQ_REQ);
    zsocket_connect (client, "ipc://frontend.ipc");

    // Send request, get reply
    while (true) {
        zstr_send (client, "HELLO");
        char *reply = zstr_recv (client);
        if (!reply)
            break;
        printf ("Client: %s\n", reply);
        free (reply);
        sleep (1);
    }
    zctx_destroy (&ctx);
    return NULL;
}

// Worker using REQ socket to do load-balancing
//
static void *
worker_task (void *args)
{
    zctx_t *ctx = zctx_new ();
    void *worker = zsocket_new (ctx, ZMQ_REQ);
    zsocket_connect (worker, "ipc://backend.ipc");

    // Tell broker we're ready for work
    zframe_t *frame = zframe_new (WORKER_READY, 1);
    zframe_send (&frame, worker, 0);

    // Process messages as they arrive
    while (true) {
        zmsg_t *msg = zmsg_recv (worker);
        if (!msg)
            break; // Interrupted
        zframe_reset (zmsg_last (msg), "OK", 2);
        zmsg_send (&msg, worker);
    }
    zctx_destroy (&ctx);
    return NULL;
}

// Now we come to the main task. This has the identical functionality to
// the previous lbbroker broker example, but uses CZMQ to start child
// threads, to hold the list of workers, and to read and send messages:

int main (void)
{
    zctx_t *ctx = zctx_new ();
    void *frontend = zsocket_new (ctx, ZMQ_ROUTER);
    void *backend = zsocket_new (ctx, ZMQ_ROUTER);
    zsocket_bind (frontend, "ipc://frontend.ipc");
    zsocket_bind (backend, "ipc://backend.ipc");

    int client_nbr;
    for (client_nbr = 0; client_nbr < NBR_CLIENTS; client_nbr++)
        zthread_new (client_task, NULL);
    int worker_nbr;
    for (worker_nbr = 0; worker_nbr < NBR_WORKERS; worker_nbr++)
        zthread_new (worker_task, NULL);

    // Queue of available workers
    zlist_t *workers = zlist_new ();

    // Here is the main loop for the load balancer. It works the same way
    // as the previous example, but is a lot shorter because CZMQ gives
    // us an API that does more with fewer calls:
    while (true) {
        zmq_pollitem_t items [] = {
            { backend, 0, ZMQ_POLLIN, 0 },
            { frontend, 0, ZMQ_POLLIN, 0 }
        };
        // Poll frontend only if we have available workers
        int rc = zmq_poll (items, zlist_size (workers)? 2: 1, -1);
        if (rc == -1)
            break; // Interrupted

        // Handle worker activity on backend
        if (items [0].revents & ZMQ_POLLIN) {
            // Use worker identity for load-balancing
            zmsg_t *msg = zmsg_recv (backend);
            if (!msg)
                break; // Interrupted
            zframe_t *identity = zmsg_unwrap (msg);
            zlist_append (workers, identity);

            // Forward message to client if it's not a READY
            zframe_t *frame = zmsg_first (msg);
            if (memcmp (zframe_data (frame), WORKER_READY, 1) == 0)
                zmsg_destroy (&msg);
            else
                zmsg_send (&msg, frontend);
        }
        if (items [1].revents & ZMQ_POLLIN) {
            // Get client request, route to first available worker
            zmsg_t *msg = zmsg_recv (frontend);
            if (msg) {
                zmsg_wrap (msg, (zframe_t *) zlist_pop (workers));
                zmsg_send (&msg, backend);
            }
        }
    }
    // When we're done, clean up properly
    while (zlist_size (workers)) {
        zframe_t *frame = (zframe_t *) zlist_pop (workers);
        zframe_destroy (&frame);
    }
    zlist_destroy (&workers);
    zctx_destroy (&ctx);
    return 0;
}
~~~

;One thing CZMQ provides is clean interrupt handling. This means that Ctrl-C will cause any blocking ØMQ call to exit with a return code -1 and errno set to EINTR. The high-level recv methods will return NULL in such cases. So, you can cleanly exit a loop like this:

CZMQがやっていることのひとつはに割り込み処理があります。
通常のØMQのブロッキングAPIは、Ctrl-Cを押した時にはerrnoにEINTRを設定して処理を中断しますが、高級APIの受信関数は単純にNULLを返します。
ですので、この様な単純なループだけで行儀よくに終了することが出来ています。

~~~
while (true) {
    zstr_send (client, "Hello");
    char *reply = zstr_recv (client);
    if (!reply)
        break; // Interrupted
    printf ("Client: %s\n", reply);
    free (reply);
    sleep (1);
}
~~~

;Or, if you're calling zmq_poll(), test on the return code:

あと、zmq_poll()を呼び出す時は返り値を確認して下さい。

~~~
if (zmq_poll (items, 2, 1000 * 1000) == -1)
    break; // Interrupted
~~~

;The previous example still uses zmq_poll(). So how about reactors? The CZMQ zloop reactor is simple but functional. It lets you:

先ほどのサンプルコードではまだzmq_poll()を使用しています。
リアクターはどうなったのでしょうか。
CZMQのzloopリアクターは単純かつ機能的です。

これは以下のことを行えます。

;* Set a reader on any socket, i.e., code that is called whenever the socket has input.
;* Cancel a reader on a socket.
;* Set a timer that goes off once or multiple times at specific intervals.
;* Cancel a timer.

* ソケットに対して処理関数をセット出来ます。これはソケットにメッセージが到達した時に呼び出されるコードの事です。
* ソケットと処理関数を取り外します。
* 指定した間隔でタイムアウトを発生させるタイマーを設定出来ます。
* タイマーのキャンセル出来ます。

;zloop of course uses zmq_poll() internally. It rebuilds its poll set each time you add or remove readers, and it calculates the poll timeout to match the next timer. Then, it calls the reader and timer handlers for each socket and timer that need attention.

zloopは内部的に`zmq_poll()`を利用しています。
これは、処理関数を設定し、次のタイムアウト時間を計算してソケットの監視します。
そして、処理関数と必要に応じてタイマー関数を呼び出します。

;When we use a reactor pattern, our code turns inside out. The main logic looks like this:

リアクターパターンを利用することで、ループが除去されます。
メインループのコードはこんな風になるでしょう。

~~~
zloop_t *reactor = zloop_new ();
zloop_reader (reactor, self->backend, s_handle_backend, self);
zloop_start (reactor);
zloop_destroy (&reactor);
~~~

;The actual handling of messages sits inside dedicated functions or methods. You may not like the style—it's a matter of taste. What it does help with is mixing timers and socket activity. In the rest of this text, we'll use zmq_poll() in simpler cases, and zloop in more complex examples.

実際のメッセージ処理は指定した処理関数で行われます。
このパターンはタイマー処理とソケットの処理が混ざっている場合に役立ちます。
このスタイルが気に入らない場合もあるでしょうから好みに合わせて使用して下さい。
この本では、単純なケースでは`zmq_poll()`を利用し、より複雑なケースではzloopを利用しています。

;Here is the load balancing broker rewritten once again, this time to use zloop:
以下の負荷分散ブローカーはzloopを利用して改めて書きなおしたものです。

~~~ {caption="lbbroker3: Load balancing broker using zloop in C"}
// Load-balancing broker
// Demonstrates use of the CZMQ API and reactor style
//
// The client and worker tasks are identical from the previous example.

#include "czmq.h"
#define NBR_CLIENTS 10
#define NBR_WORKERS 3
#define WORKER_READY "\001" // Signals worker is ready

// Basic request-reply client using REQ socket
//
static void *
client_task (void *args)
{
    zctx_t *ctx = zctx_new ();
    void *client = zsocket_new (ctx, ZMQ_REQ);
    zsocket_connect (client, "ipc://frontend.ipc");

    // Send request, get reply
    while (true) {
        zstr_send (client, "HELLO");
        char *reply = zstr_recv (client);
        if (!reply)
            break;
        printf ("Client: %s\n", reply);
        free (reply);
        sleep (1);
    }
    zctx_destroy (&ctx);
    return NULL;
}

// Worker using REQ socket to do load-balancing
//
static void *
worker_task (void *args)
{
    zctx_t *ctx = zctx_new ();
    void *worker = zsocket_new (ctx, ZMQ_REQ);
    zsocket_connect (worker, "ipc://backend.ipc");

    // Tell broker we're ready for work
    zframe_t *frame = zframe_new (WORKER_READY, 1);
    zframe_send (&frame, worker, 0);

    // Process messages as they arrive
    while (true) {
        zmsg_t *msg = zmsg_recv (worker);
        if (!msg)
            break; // Interrupted
        //zframe_print (zmsg_last (msg), "Worker: ");
        zframe_reset (zmsg_last (msg), "OK", 2);
        zmsg_send (&msg, worker);
    }
    zctx_destroy (&ctx);
    return NULL;
}

// Our load-balancer structure, passed to reactor handlers
typedef struct {
    void *frontend; // Listen to clients
    void *backend; // Listen to workers
    zlist_t *workers; // List of ready workers
} lbbroker_t;

// In the reactor design, each time a message arrives on a socket, the
// reactor passes it to a handler function. We have two handlers; one
// for the frontend, one for the backend:

// Handle input from client, on frontend
int s_handle_frontend (zloop_t *loop, zmq_pollitem_t *poller, void *arg)
{
    lbbroker_t *self = (lbbroker_t *) arg;
    zmsg_t *msg = zmsg_recv (self->frontend);
    if (msg) {
        zmsg_wrap (msg, (zframe_t *) zlist_pop (self->workers));
        zmsg_send (&msg, self->backend);

        // Cancel reader on frontend if we went from 1 to 0 workers
        if (zlist_size (self->workers) == 0) {
            zmq_pollitem_t poller = { self->frontend, 0, ZMQ_POLLIN };
            zloop_poller_end (loop, &poller);
        }
    }
    return 0;
}

// Handle input from worker, on backend
int s_handle_backend (zloop_t *loop, zmq_pollitem_t *poller, void *arg)
{
    // Use worker identity for load-balancing
    lbbroker_t *self = (lbbroker_t *) arg;
    zmsg_t *msg = zmsg_recv (self->backend);
    if (msg) {
        zframe_t *identity = zmsg_unwrap (msg);
        zlist_append (self->workers, identity);

        // Enable reader on frontend if we went from 0 to 1 workers
        if (zlist_size (self->workers) == 1) {
            zmq_pollitem_t poller = { self->frontend, 0, ZMQ_POLLIN };
            zloop_poller (loop, &poller, s_handle_frontend, self);
        }
        // Forward message to client if it's not a READY
        zframe_t *frame = zmsg_first (msg);
        if (memcmp (zframe_data (frame), WORKER_READY, 1) == 0)
            zmsg_destroy (&msg);
        else
            zmsg_send (&msg, self->frontend);
    }
    return 0;
}

// And the main task now sets up child tasks, then starts its reactor.
// If you press Ctrl-C, the reactor exits and the main task shuts down.
// Because the reactor is a CZMQ class, this example may not translate
// into all languages equally well.

int main (void)
{
    zctx_t *ctx = zctx_new ();
    lbbroker_t *self = (lbbroker_t *) zmalloc (sizeof (lbbroker_t));
    self->frontend = zsocket_new (ctx, ZMQ_ROUTER);
    self->backend = zsocket_new (ctx, ZMQ_ROUTER);
    zsocket_bind (self->frontend, "ipc://frontend.ipc");
    zsocket_bind (self->backend, "ipc://backend.ipc");

    int client_nbr;
    for (client_nbr = 0; client_nbr < NBR_CLIENTS; client_nbr++)
        zthread_new (client_task, NULL);
    int worker_nbr;
    for (worker_nbr = 0; worker_nbr < NBR_WORKERS; worker_nbr++)
        zthread_new (worker_task, NULL);

    // Queue of available workers
    self->workers = zlist_new ();

    // Prepare reactor and fire it up
    zloop_t *reactor = zloop_new ();
    zmq_pollitem_t poller = { self->backend, 0, ZMQ_POLLIN };
    zloop_poller (reactor, &poller, s_handle_backend, self);
    zloop_start (reactor);
    zloop_destroy (&reactor);

    // When we're done, clean up properly
    while (zlist_size (self->workers)) {
        zframe_t *frame = (zframe_t *) zlist_pop (self->workers);
        zframe_destroy (&frame);
    }
    zlist_destroy (&self->workers);
    zctx_destroy (&ctx);
    free (self);
    return 0;
}
~~~

;Getting applications to properly shut down when you send them Ctrl-C can be tricky. If you use the zctx class it'll automatically set up signal handling, but your code still has to cooperate. You must break any loop if zmq_poll returns -1 or if any of the zstr_recv, zframe_recv, or zmsg_recv methods return NULL. If you have nested loops, it can be useful to make the outer ones conditional on !zctx_interrupted.

Ctrl-Cを送信すると、アプリケーションは行儀よく終了します。
`zctx_new()`でコンテキストを作成した場合、自動的にシグナルハンドラが設定されますので、アプリケーションはこれに連動しなければなりません。
従来の方法だと、zmq_pollの返り値が-1であるかどうかや、zstr_recv, zframe_recv, zmsg_recvなどの返り値がNULLかどうかを確認しなければなりませんでしたがもはや必要ありません。
ネストしたループがある場合には、zctx_interruptedを利用して割り込みを確認する事ができます。

;If you're using child threads, they won't receive the interrupt. To tell them to shutdown, you can either:

子スレッドでは、割り込みシグナルを受け取ることが出来ません。
子スレッドに終了させるには以下の方法があります。

;* Destroy the context, if they are sharing the same context, in which case any blocking calls they are waiting on will end with ETERM.
;* Send them shutdown messages, if they are using their own contexts. For this you'll need some socket plumbing.

* 共有しているコンテキストを破棄します。そうするとブロッキングしている処理がETERMを設定して戻ってきます。
* 独自のコンテキストを利用している場合にはメッセージを送信して終了を通知します。もちろんソケット同士で接続しておく必要があります。

## 非同期クライアント・サーバーパターン
;In the ROUTER to DEALER example, we saw a 1-to-N use case where one server talks asynchronously to multiple workers. We can turn this upside down to get a very useful N-to-1 architecture where various clients talk to a single server, and do this asynchronously.

ROUTERからDEALERに接続する例では、単一のサーバーが複数のワーカーに非同期で1対多の通信を行う例を見てきました。
これとは逆に、複数のクライアントが単一のサーバーに非同期で通信を行う多対1のアーキテクチャも簡単に構築することが出来ます。

![非同期なクライアント・サーバー](images/fig37.eps)

;Here's how it works:

これは以下のように機能します。

;* Clients connect to the server and send requests.
;* For each request, the server sends 0 or more replies.
;* Clients can send multiple requests without waiting for a reply.
;* Servers can send multiple replies without waiting for new requests.

* クライアント側がサーバーに対してリクエストを送信します。
* サーバーは各リクエストに対して、0以上の応答を返します。
* クライアントは応答を待たずに複数のリクエストを送信することが出来ます。
* サーバーは新しいリクエストを待たずに複数の応答を返すことが出来ます。

;Here's code that shows how this works:

以下にサンプルコードを示します。

~~~ {caption="asyncsrv: Asynchronous client/server in C"}
// Asynchronous client-to-server (DEALER to ROUTER)
//
// While this example runs in a single process, that is to make
// it easier to start and stop the example. Each task has its own
// context and conceptually acts as a separate process.

#include "czmq.h"

// This is our client task
// It connects to the server, and then sends a request once per second
// It collects responses as they arrive, and it prints them out. We will
// run several client tasks in parallel, each with a different random ID.

static void *
client_task (void *args)
{
    zctx_t *ctx = zctx_new ();
    void *client = zsocket_new (ctx, ZMQ_DEALER);

    // Set random identity to make tracing easier
    char identity [10];
    sprintf (identity, "%04X-%04X", randof (0x10000), randof (0x10000));
    zsocket_set_identity (client, identity);
    zsocket_connect (client, "tcp://localhost:5570");

    zmq_pollitem_t items [] = { { client, 0, ZMQ_POLLIN, 0 } };
    int request_nbr = 0;
    while (true) {
        // Tick once per second, pulling in arriving messages
        int centitick;
        for (centitick = 0; centitick < 100; centitick++) {
            zmq_poll (items, 1, 10 * ZMQ_POLL_MSEC);
            if (items [0].revents & ZMQ_POLLIN) {
                zmsg_t *msg = zmsg_recv (client);
                zframe_print (zmsg_last (msg), identity);
                zmsg_destroy (&msg);
            }
        }
        zstr_send (client, "request #%d", ++request_nbr);
    }
    zctx_destroy (&ctx);
    return NULL;
}

// This is our server task.
// It uses the multithreaded server model to deal requests out to a pool
// of workers and route replies back to clients. One worker can handle
// one request at a time but one client can talk to multiple workers at
// once.

static void server_worker (void *args, zctx_t *ctx, void *pipe);

void *server_task (void *args)
{
    // Frontend socket talks to clients over TCP
    zctx_t *ctx = zctx_new ();
    void *frontend = zsocket_new (ctx, ZMQ_ROUTER);
    zsocket_bind (frontend, "tcp://*:5570");

    // Backend socket talks to workers over inproc
    void *backend = zsocket_new (ctx, ZMQ_DEALER);
    zsocket_bind (backend, "inproc://backend");

    // Launch pool of worker threads, precise number is not critical
    int thread_nbr;
    for (thread_nbr = 0; thread_nbr < 5; thread_nbr++)
        zthread_fork (ctx, server_worker, NULL);

    // Connect backend to frontend via a proxy
    zmq_proxy (frontend, backend, NULL);

    zctx_destroy (&ctx);
    return NULL;
}

// Each worker task works on one request at a time and sends a random number
// of replies back, with random delays between replies:

static void
server_worker (void *args, zctx_t *ctx, void *pipe)
{
    void *worker = zsocket_new (ctx, ZMQ_DEALER);
    zsocket_connect (worker, "inproc://backend");

    while (true) {
        // The DEALER socket gives us the reply envelope and message
        zmsg_t *msg = zmsg_recv (worker);
        zframe_t *identity = zmsg_pop (msg);
        zframe_t *content = zmsg_pop (msg);
        assert (content);
        zmsg_destroy (&msg);

        // Send 0..4 replies back
        int reply, replies = randof (5);
        for (reply = 0; reply < replies; reply++) {
            // Sleep for some fraction of a second
            zclock_sleep (randof (1000) + 1);
            zframe_send (&identity, worker, ZFRAME_REUSE + ZFRAME_MORE);
            zframe_send (&content, worker, ZFRAME_REUSE);
        }
        zframe_destroy (&identity);
        zframe_destroy (&content);
    }
}

// The main thread simply starts several clients and a server, and then
// waits for the server to finish.

int main (void)
{
    zthread_new (client_task, NULL);
    zthread_new (client_task, NULL);
    zthread_new (client_task, NULL);
    zthread_new (server_task, NULL);
    zclock_sleep (5 * 1000); // Run for 5 seconds then quit
    return 0;
}
~~~

;The example runs in one process, with multiple threads simulating a real multiprocess architecture. When you run the example, you'll see three clients (each with a random ID), printing out the replies they get from the server. Look carefully and you'll see each client task gets 0 or more replies per request.

このサンプルコードは単一プロセスで動作しますが、ここでのマルチスレッドはマルチプロセスアーキテクチャをシミュレートしていると思って見て下さい。
サンプルコードを実行すると、3つのクライアントはサーバーに対してリクエストを行い、応答を出力します。
注意深く見ると、クライアントは0以上の応答を受け取っていることが分かるでしょう。

;Some comments on this code:

コードに補足すると、

;* The clients send a request once per second, and get zero or more replies back. To make this work using zmq_poll(), we can't simply poll with a 1-second timeout, or we'd end up sending a new request only one second after we received the last reply. So we poll at a high frequency (100 times at 1/100th of a second per poll), which is approximately accurate.
;* The server uses a pool of worker threads, each processing one request synchronously. It connects these to its frontend socket using an internal queue. It connects the frontend and backend sockets using a zmq_proxy() call.

* クライアントは1秒毎に1つのリクエストを送信し、複数の応答を受け取ります。これにはzmq_poll()を利用しますが、単純に1秒のタイムアウトしまうと1秒間何も出来なくなってしまいますので、高頻度(100分の1秒に1回の頻度)でポーリングを行うようにします。
* サーバーはワーカースレッドを複数用意していてリクエストを同期的に処理します。接続をフロントエンドソケットでキューイングし、zmq_proxy()を呼び出してバックエンドソケットに接続します。

![非同期サーバーの詳細](images/fig38.eps)

;Note that we're doing DEALER to ROUTER dialog between client and server, but internally between the server main thread and workers, we're doing DEALER to DEALER. If the workers were strictly synchronous, we'd use REP. However, because we want to send multiple replies, we need an async socket. We do not want to route replies, they always go to the single server thread that sent us the request.

クライアントとサーバー間ではDEALER対ROUTERの通信を行っていますが、内部的なサーバーとワーカーの通信では、DEALER対DEALERの通信を行っていることに注意して下さい。
もしワーカーが完全に同期的に動作する場合はREPソケットを利用するでしょう。
しかしここでは複数の応答を行うために非同期なソケットが必要です。
応答をルーティングするようなことはやりたくないので、単一のサーバーに対して応答を返すようにしてやります。

;Let's think about the routing envelope. The client sends a message consisting of a single frame. The server thread receives a two-frame message (original message prefixed by client identity). We send these two frames on to the worker, which treats it as a normal reply envelope, returns that to us as a two frame message. We then use the first frame as an identity to route the second frame back to the client as a reply.

ルーティングのエンベロープについて考えてみましょう。
クライアントは単一のフレームからなるメッセージを送信し、サーバースレッドはクライアントのIDが付け加えられた2つのフレームを受信します。
この2つのフレームをワーカーに送信すると、通常の応答エンベロープとして扱われ2つのフレームが返ってきます。そして最初のフレームはクライアントのIDとしてルーテイングし、後続のフレームをクライアントに応答します。

;It looks something like this:

以下の様になります

~~~
     client          server       frontend       worker
   [ DEALER ]<---->[ ROUTER <----> DEALER <----> DEALER ]
             1 part         2 parts       2 parts
~~~

;Now for the sockets: we could use the load balancing ROUTER to DEALER pattern to talk to workers, but it's extra work. In this case, a DEALER to DEALER pattern is probably fine: the trade-off is lower latency for each request, but higher risk of unbalanced work distribution. Simplicity wins in this case.

ここでROUTERからDEALERへの負荷分散パターンをを利用することも出来ますが余計な作業が必要です。
この場合では、各リクエストのレイテンシが少ないDEALERからDEALERへのパターンを利用するのが最も適切ではありますが、分散が平均化されないリスクがありますのでこれらがトレードオフになります。

;When you build servers that maintain stateful conversations with clients, you will run into a classic problem. If the server keeps some state per client, and clients keep coming and going, eventually it will run out of resources. Even if the same clients keep connecting, if you're using default identities, each connection will look like a new one.

クライアントとステートフルなやりとりを行うサーバーを構築する際、あなたは古典的な問題に遭遇するでしょう。
サーバーがクライアント毎の状態を保持する場合、クライアントが接続を繰り返す内にリソースを食いつぶしてしまうという問題です。
既定のIDを利用すると、こういう事になってしまいます。

;We cheat in the above example by keeping state only for a very short time (the time it takes a worker to process a request) and then throwing away the state. But that's not practical for many cases. To properly manage client state in a stateful asynchronous server, you have to:

これは短い時間だけ状態を保持し、一定の時間が経過した場合に状態を捨てることでこの問題を回避することが出来ます。
しかしこれは多くの場合で実用的ではありません。
ステートフルな非同期サーバーでは以下のようにしてクライアントの状態を適切に管理する必要があります。

;* Do heartbeating from client to server. In our example, we send a request once per second, which can reliably be used as a heartbeat.
;* Store state using the client identity (whether generated or explicit) as key.
;* Detect a stopped heartbeat. If there's no request from a client within, say, two seconds, the server can detect this and destroy any state it's holding for that client.

* クライアントからサーバーに対して定期的に疎通確認を行います。先ほどの例では1秒間に一度の疎通確認を行うことが出来ます。
* クライアントIDをキーとして状態を保持します。
* 疎通確認が失敗し、例えば2秒間クライアントからのリクエストが行われない場合は保持しているクライアントの状態を破棄します。

## ブローカー間ルーティングの実例
;Let's take everything we've seen so far, and scale things up to a real application. We'll build this step-by-step over several iterations. Our best client calls us urgently and asks for a design of a large cloud computing facility. He has this vision of a cloud that spans many data centers, each a cluster of clients and workers, and that works together as a whole. Because we're smart enough to know that practice always beats theory, we propose to make a working simulation using ØMQ. Our client, eager to lock down the budget before his own boss changes his mind, and having read great things about ØMQ on Twitter, agrees.

それでは、これまで見てきたものを実際のアプリケーションに応用してみましょう。
これらを一歩一歩説明しながら作っていきます。
私達の顧客が緊急に私達を呼び出して大規模なクラウドコンピューティング施設を設計するように要求してきたとします。
彼らは多くのデータセンターにわたって動作するクライアントとワーカーのクラスターが協調することで全体が機能するクラウドを構想しています。
我々には理論に裏付けされた知識と経験が十分にあるので、私達はØMQを使用してシュミレーションを行うことを提案します。
その顧客は自分の上司が心変わりする前に、Twitter上でのØMQの賞賛を読ませて予算を確保することに同意させます。

### 要件の確認
;Several espressos later, we want to jump into writing code, but a little voice tells us to get more details before making a sensational solution to entirely the wrong problem. "What kind of work is the cloud doing?", we ask.

エスプレッソでも飲んでコードを書き始めたいところですが、重大な問題が発生する前により詳細な要件を確認しろと心の中で何かが囁きます。
そこで顧客に「クラウドでどんな事をやりたいのですか?」と尋ねます。

;The client explains:

顧客はこう答えます。

;* Workers run on various kinds of hardware, but they are all able to handle any task. There are several hundred workers per cluster, and as many as a dozen clusters in total.
;* Clients create tasks for workers. Each task is an independent unit of work and all the client wants is to find an available worker, and send it the task, as soon as possible. There will be a lot of clients and they'll come and go arbitrarily.
;* The real difficulty is to be able to add and remove clusters at any time. A cluster can leave or join the cloud instantly, bringing all its workers and clients with it.
;* If there are no workers in their own cluster, clients' tasks will go off to other available workers in the cloud.
;* Clients send out one task at a time, waiting for a reply. If they don't get an answer within X seconds, they'll just send out the task again. This isn't our concern; the client API does it already.
;* Workers process one task at a time; they are very simple beasts. If they crash, they get restarted by whatever script started them.

* ワーカーは様々なハードウェアで動作し、あらゆる処理を行います。クラスターは数十個ほどあり、そのクラスター毎に数百ほどのワーカーを持っています。
* クライアントは独立した処理タスクを生成し、即座に空いているワーカーを見つけてタスクを送信します。膨大な数のクライアントが存在し、任意のタイミングで増えたり減ったりもします。
* 本当に難しい所は任意のタイミングでクラスターを追加したり外したり出来るようにすることです。クラスターは全てのワーカーとクライアントを引き連れて瞬時に追加したり外すことが出来なくてはなりません。
* クラスターにワーカーが存在しない場合、クライアントの処理タスクは他のクラスターに存在するワーカーに送信します。
* クライアントがひとつのタスクを送信すると、応答が返ってくるまで待ちます。一定時間待って応答が帰ってこなかった場合は再送します。これについてはクライアントのAPIが勝手に行ってくれるので特に何もする必要はありません。
* ワーカーは1度にひとつのタスクしか処理しません。もしワーカーがクラッシュしてしまった場合は起動したスクリプトで再起動します。

;So we double-check to make sure that we understood this correctly:

これを正確に理解するために再確認します。

;* "There will be some kind of super-duper network interconnect between clusters, right?", we ask. The client says, "Yes, of course, we're not idiots."
;* "What kind of volumes are we talking about?", we ask. The client replies, "Up to a thousand clients per cluster, each doing at most ten requests per second. Requests are small, and replies are also small, no more than 1K bytes each."

* 「そのクラスター間のネットワーク接続は十分高速なんでしょうね?」と尋ねます。「もちろん、そこまで我々は馬鹿じゃない」と顧客は言います。
* 「通信料はどれくらいですか?」と尋ねます。「1クラスターあたりのクライアント数は最大1000台程度で、各クライアントはせいぜい秒間10リクエスト程度でしょう。リクエストと応答のサイズは小さく、1Kバイトを超えないでしょう。」と答えました。

;So we do a little calculation and see that this will work nicely over plain TCP. 2,500 clients x 10/second x 1,000 bytes x 2 directions = 50MB/sec or 400Mb/sec, not a problem for a 1Gb network.

これを聞いて私達は通常のTCPで上手く動作するか簡単に計算します。
2,500 クライアント x 10/秒 x 1,000 バイト x 2 方向 = 50MB/秒 〜 400Mb/秒。1Gbネットワークで問題なさそうだ。

;It's a straightforward problem that requires no exotic hardware or protocols, just some clever routing algorithms and careful design. We start by designing one cluster (one data center) and then we figure out how to connect clusters together.

これは特別なハードウェアやプロトコルを利用しなければ簡単な問題です。
ただし、特殊なルーティングアルゴリズムを使用する場合は注意して設計して下さい。
まず1つのクラスター(データセンター)で設計し、続いて複数のクラスター間の接続方法を考えます。

### 単一クラスターのアーキテクチャ
;Workers and clients are synchronous. We want to use the load balancing pattern to route tasks to workers. Workers are all identical; our facility has no notion of different services. Workers are anonymous; clients never address them directly. We make no attempt here to provide guaranteed delivery, retry, and so on.

ワーカーとクライアントは同期的に通信します。
ここでは負荷分散パターンを利用してタスクをワーカーにルーティングします。
ワーカーは全て同一のサービスを提供します。
ワーカーは匿名であり、固定的なアドレスを持ちません。
再試行を自動的に行いますので通信の保証については特に考えなくても良いでしょう。

;For reasons we already examined, clients and workers won't speak to each other directly. It makes it impossible to add or remove nodes dynamically. So our basic model consists of the request-reply message broker we saw earlier.

これまで検討してきたように、ノードの追加や削除が動的に行えなくなるのでクライアントとワーカーは直接通信しません。
従ってこれまでに見てきたリクエスト・応答のメッセージブローカーを基本的なモデルとします。

![クラスターのアーキテクチャ](images/fig39.eps)

### 複数クラスターへの拡張
;Now we scale this out to more than one cluster. Each cluster has a set of clients and workers, and a broker that joins these together.

さて、複数のクラスターへ拡張してみましょう。
各クラスターは接続されたクライアントとワーカーとブローカーで構成されます。

![複数のクラスター](images/fig40.eps)

;The question is: how do we get the clients of each cluster talking to the workers of the other cluster? There are a few possibilities, each with pros and cons:

ここで問題です。クライアントはどの様にして他のクラスターに居るワーカーと通信すればよいのでしょうか。これには幾つかの方法があり、長所と短所があります。

;* Clients could connect directly to both brokers. The advantage is that we don't need to modify brokers or workers. But clients get more complex and become aware of the overall topology. If we want to add a third or forth cluster, for example, all the clients are affected. In effect we have to move routing and failover logic into the clients and that's not nice.
;* Workers might connect directly to both brokers. But REQ workers can't do that, they can only reply to one broker. We might use REPs but REPs don't give us customizable broker-to-worker routing like load balancing does, only the built-in load balancing. That's a fail; if we want to distribute work to idle workers, we precisely need load balancing. One solution would be to use ROUTER sockets for the worker nodes. Let's label this "Idea #1".
;* Brokers could connect to each other. This looks neatest because it creates the fewest additional connections. We can't add clusters on the fly, but that is probably out of scope. Now clients and workers remain ignorant of the real network topology, and brokers tell each other when they have spare capacity. Let's label this "Idea #2".

* クライアントを他のブローカーに直接接続する方法。これにはブローカーとワーカーを変更する必要がないという利点があります。しかしクライアントはトポロジーを意識する必要がありますのでより複雑になります。例えば3つ目、4つめのクラスターを追加する際に全てのクライアントが影響を受けます。これはルーティングやフェイルオーバーのロジックにも影響してしまうのであまり良くありません。
* ワーカーが他のブローカに接続する方法。残念ながらREQソケットのワーカーは1つのブローカーにしか応答を返さないのでこれを行うことが出来ません。そこでREPソケットを使おうとするかもしれませんが、REPソケットは負荷分散を行うようなルーティング機能を提供していません。これでは空いているワーカーを探して分散する機能を実現できません。唯一の方法はROUTERソケットを利用することです。これをアイディア#1としておきます。
* ブローカー同士を相互に接続する方法。これは接続数を少なくできるので賢い方法の様に見えます。クラスターを動的に追加することが難しくなりますが、これは許容範囲でしょう。クライアントとワーカーは実際のネットワークトポロジに関して何も知らなくて構いません。またブローカーはお互いの処理容量を教えあうことが可能です。これをアイディア#2とします。

;Let's explore Idea #1. In this model, we have workers connecting to both brokers and accepting jobs from either one.

アイディア#2について説明していきましょう。
このモデルでは、ワーカーは2つのブローカーに接続してタスクを受け付けています。

![アイディア#1: ワーカーのクロス接続](images/fig41.eps)

;It looks feasible. However, it doesn't provide what we wanted, which was that clients get local workers if possible and remote workers only if it's better than waiting. Also workers will signal "ready" to both brokers and can get two jobs at once, while other workers remain idle. It seems this design fails because again we're putting routing logic at the edges.

これはもっともな方法に見えますが私達が求めているものとは少し違います。
クライアントはまずローカルクラスターのワーカーを利用し、これが利用できない場合にリモートクラスターのワーカーを使用して欲しいのです。また、ワーカーが2つのブローカーに対して「準備完了」シグナルを送信すると、同時に2つのタスクを受け取る可能性があります。どうやらこれは設計に失敗した様だ。

;So, idea #2 then. We interconnect the brokers and don't touch the clients or workers, which are REQs like we're used to.

ならばアイディア#2で行きます。
ブローカー同士の相互接続しますが、クライアントとワーカーがREQソケットを利用していることには触れないで下さい。

![アイディア#2: ブローカーの相互接続](images/fig42.eps)

;This design is appealing because the problem is solved in one place, invisible to the rest of the world. Basically, brokers open secret channels to each other and whisper, like camel traders, "Hey, I've got some spare capacity. If you have too many clients, give me a shout and we'll deal".

この設計は、全体を隠蔽化して局所的なクラスター内で自己完結している所が魅力的です。ブローカーは常時専用の回線で接続し、こんな風にお互いに囁き合っています。「おい、俺の処理容量は空きがあるぜ、そっちが忙しいようならこちらでタスクを引き受けるよ。」

;In effect it is just a more sophisticated routing algorithm: brokers become subcontractors for each other. There are other things to like about this design, even before we play with real code:

実際にはこれはブローカーがお互いに下請け業者となるという高度なルーティングアルゴリズムです。
この設計にはまだまだ特徴があります。

;* It treats the common case (clients and workers on the same cluster) as default and does extra work for the exceptional case (shuffling jobs between clusters).
;* It lets us use different message flows for the different types of work. That means we can handle them differently, e.g., using different types of network connection.
;* It feels like it would scale smoothly. Interconnecting three or more brokers doesn't get overly complex. If we find this to be a problem, it's easy to solve by adding a super-broker.

* クライアントとワーカーは既定ではいつも通りの動作を行います。タスクが他のクラスタに問い合わせるような場合は例外的に特別な処理を行います。
* 処理の種別に応じて異なるメッセージの経路を利用出来るようになります。これは異なるネットワーク接続を使い分ける事を意味しています。
* 高い拡張性。3つ以上のブローカーを相互接続する場合は複雑になってきますが、もしこれが問題になる場合、超越的なブローカーを配置すれば良いでしょう。

;We'll now make a worked example. We'll pack an entire cluster into one process. That is obviously not realistic, but it makes it simple to simulate, and the simulation can accurately scale to real processes. This is the beauty of ØMQ—you can design at the micro-level and scale that up to the macro-level. Threads become processes, and then become boxes and the patterns and logic remain the same. Each of our "cluster" processes contains client threads, worker threads, and a broker thread.

それでは実際に動作するコードを書いてみましょう。
ここでは1クラスターを1つのプロセスに押し込めます。
これは現実的ではありませんが、単純なシミュレートだと思って下さい。
このシミュレーションからマルチプロセスに拡張することは簡単です。
ミクロのレベルで行った設計をマクロのレベルに拡張できる事こそがØMQの美学です。
パターンやロジックはそのままで、スレッドをプロセスに移行し、さらに別サーバーで動作させることが可能です。
これから作る「クラスター」プロセスにはクライアントスレッドとワーカースレッド、およびブローカースレッドが含まれています。

;We know the basic model well by now:

基本的なモデルは既に知っている通りです。

;* The REQ client (REQ) threads create workloads and pass them to the broker (ROUTER).
;* The REQ worker (REQ) threads process workloads and return the results to the broker (ROUTER).
;* The broker queues and distributes workloads using the load balancing pattern.

* REQクライアントスレッドはタスクを生成し、ブローカーに渡します。(REQソケットからROUTERソケットへ)
* REQワーカースレッドはタスクを処理し、ブローカーに応答します。(REQソケットからROUTERソケットへ)
* ブローカーはキューイングし、負荷分散パターンを利用してタスクを分散します。

### フェデレーションとピア接続
;There are several possible ways to interconnect brokers. What we want is to be able to tell other brokers, "we have capacity", and then receive multiple tasks. We also need to be able to tell other brokers, "stop, we're full". It doesn't need to be perfect; sometimes we may accept jobs we can't process immediately, then we'll do them as soon as possible.

ブローカーを相互接続するには幾つかの方法があります。
私達が欲しいのは「自分の処理容量」を別のブローカに伝え、複数のタスクを受け取る機能です。
また、別のブローカーに「もう一杯だ、送らないでくれ」とつらえる機能も必要です。
これは完璧である必要はありません、タスクを受け付けたら可能な限り早く処理できれば良しとします。

;The simplest interconnect is federation, in which brokers simulate clients and workers for each other. We would do this by connecting our frontend to the other broker's backend socket. Note that it is legal to both bind a socket to an endpoint and connect it to other endpoints.

最も単純な相互接続を行う方法はフェデレーションモデルです。これはお互いにクライアントとワーカーをシミュレートします。
これはブローカーのフロントエンドから、別のブローカーのバックエンドに接続することで実現します。
この時ソケットがbindと接続の両方を行えるかどうかを確認して下さい。

![フェデレーションモデルによるブローカーの相互接続](images/fig43.eps)

;This would give us simple logic in both brokers and a reasonably good mechanism: when there are no clients, tell the other broker "ready", and accept one job from it. The problem is also that it is too simple for this problem. A federated broker would be able to handle only one task at a time. If the broker emulates a lock-step client and worker, it is by definition also going to be lock-step, and if it has lots of available workers they won't be used. Our brokers need to be connected in a fully asynchronous fashion.

これは双方のブローカーにとって単純なロジックであり、そこそこ良いメカニズムです。
ワーカーが居ない場合でも他のクラスターのブローカーが「準備完了」メッセージを通知し、タスクを受け付けます。
唯一の問題はこれが単純すぎるという所です。
フェデレーションのブローカーは一度に1つのタスクしか処理できません。
ブローカーがロックステップなクライアントとワーカーをエミュレートするならば、ブローカーもそのままロックステップとなり、たとえ沢山のワーカーが居たとしても同時に利用することが出来ません。ブローカーは完全に非同期で接続する必要があります。

;The federation model is perfect for other kinds of routing, especially service-oriented architectures (SOAs), which route by service name and proximity rather than load balancing or round robin. So don't dismiss it as useless, it's just not right for all use cases.

フェデレーションモデルは様々な種類のルーティング、特にサービス指向アーキテクチャに最適です。サービス指向アーキテクチャは負荷分散ではなく、サービス種別に応じてルーティングを行います。
ですので全ての用途に適応するわけではありませんが用途によっては有効です。

;Instead of federation, let's look at a peering approach in which brokers are explicitly aware of each other and talk over privileged channels. Let's break this down, assuming we want to interconnect N brokers. Each broker has (N - 1) peers, and all brokers are using exactly the same code and logic. There are two distinct flows of information between brokers:

フェデレーションではなくピア接続を行う方法を紹介します。
この方法ではブローカーは特別な接続を通じてお互いを認識しています。
詳しく言うと、N個のブローカーで相互接続を行いたい場合、(N - 1)個のピアが存在し、これらは同じコードで動作しています。
この時、ブローカー同士の間で2種類の情報の経路が存在します。

;* Each broker needs to tell its peers how many workers it has available at any time. This can be fairly simple information—just a quantity that is updated regularly. The obvious (and correct) socket pattern for this is pub-sub. So every broker opens a PUB socket and publishes state information on that, and every broker also opens a SUB socket and connects that to the PUB socket of every other broker to get state information from its peers.
;* Each broker needs a way to delegate tasks to a peer and get replies back, asynchronously. We'll do this using ROUTER sockets; no other combination works. Each broker has two such sockets: one for tasks it receives and one for tasks it delegates. If we didn't use two sockets, it would be more work to know whether we were reading a request or a reply each time. That would mean adding more information to the message envelope.

* 各ブローカーは常にピアに対して自信の処理容量(ワーカーの数)を通知する必要があります。これはワーカーの数に変更が有った場合のみ通知される単純な情報になるでしょう。この様な用途に適したソケットパターンはpub-subです。ですから全てのブローカーはSUBソケットを利用して、各ブローカーのPUBソケットに接続してピアから情報を受け取ることになるます。
* 各ブローカーはタスクを非同期でピアに委託し、応答を受け取る必要があります。これにははROUTERソケットを利用します。これ以外の選択肢は無いでしょう。ここでブローカーは2種類のソケットを扱うことになります。ひとつはタスクを受信するためのソケットでもうひとつはタスクを委任するためのソケットです。2つのソケットを利用しない場合は幾つかの作業が必要です。この場合メッセージエンベロープに付加的な情報を追加する必要があるでしょう。

;And there is also the flow of information between a broker and its local clients and workers.

もちろんこれらの情報の経路に加えて、クラスター内のワーカーとクライアントとの接続もあります。

### 命名の儀式
;Three flows x two sockets for each flow = six sockets that we have to manage in the broker. Choosing good names is vital to keeping a multisocket juggling act reasonably coherent in our minds. Sockets do something and what they do should form the basis for their names. It's about being able to read the code several weeks later on a cold Monday morning before coffee, and not feel any pain.

3つの通信経路×2ソケットという事でブローカーは合計6つのソケットを管理する必要があります。
多くのソケットを扱う際に混乱しないようにするためには良い名前を付けることが不可欠です。
ソケットが何を行い、どの様な役割を持っているかを元に名前を決定します。
そうしなければ後々寒い月曜の朝に苦んでコードを読むことになるでしょう。

;Let's do a shamanistic naming ceremony for the sockets. The three flows are:

それでは、ソケットの命名の儀式を行いましょう。
3つの通信経路は、

;* A local request-reply flow between the broker and its clients and workers.
;* A cloud request-reply flow between the broker and its peer brokers.
;* A state flow between the broker and its peer brokers.

* ブローカーとクライアント、ワーカーの間でリクエスト・応答を行う通信経路を「local」と呼びます。
* ブローカー同士の間でリクエスト・応答を行う通信経路を「cloud」と呼びます。
* ブローカー同士で状態を通知する通信経路を「state」と呼びます。

;Finding meaningful names that are all the same length means our code will align nicely. It's not a big thing, but attention to details helps. For each flow the broker has two sockets that we can orthogonally call the frontend and backend. We've used these names quite often. A frontend receives information or tasks. A backend sends those out to other peers. The conceptual flow is from front to back (with replies going in the opposite direction from back to front).

同じ長さの名前を付けるとコードがキレイに整うのでいい感じです。
これは些細なことですが、細部への気配りです。
ブローカーは各通信経路にそれぞれフロントエンドとバックエンドソケットを持ちます。
フロントエンドからは状態やタスクを受信し、バックエンドにこれらを送信します。
リクエストはフロントエンドからバックエンドへ、応答はバックエンドからフロントへ返されると考えて下さい。

;So in all the code we write for this tutorial, we will use these socket names:

という訳でこのチュートリアルでは以下のソケット名を使用します。

;* localfe and localbe for the local flow.
;* cloudfe and cloudbe for the cloud flow.
;* statefe and statebe for the state flow.

* 「local」の通信経路で利用するソケットは「localfe」と「localbe」
* 「cloud」の通信経路で利用するソケットは「cloudfe」と「cloudbe」
* 「state」の通信経路で利用するソケットは「statefe」と「statebe」

;For our transport and because we're simulating the whole thing on one box, we'll use ipc for everything. This has the advantage of working like tcp in terms of connectivity (i.e., it's a disconnected transport, unlike inproc), yet we don't need IP addresses or DNS names, which would be a pain here. Instead, we will use ipc endpoints called something-local, something-cloud, and something-state, where something is the name of our simulated cluster.

ここでは1サーバーで全てをシミュレートしているので、通信方式は全てIPC(プロセス間通信)を利用します。
これはTCPで言う所の接続性を持ち、IPアドレスやDNS名を必要としません。
そして、ここではエンドポイントを呼ぶ時はシミュレートするクラスター名を付けて〜のlocal、〜のcloud、〜のstateという言い方をします。

;You might be thinking that this is a lot of work for some names. Why not call them s1, s2, s3, s4, etc.? The answer is that if your brain is not a perfect machine, you need a lot of help when reading code, and we'll see that these names do help. It's easier to remember "three flows, two directions" than "six different sockets".

ソケットに名前を付ける作業が面倒になって、単純にS1, S2, S3, S4で良いのではないかと考えていませんか?
あなたの脳は完璧な機械ではありませんのでコードを読むときには名前による手助けが必要です。
「6種類のソケット」と覚えるより、「3つの経路と、2つの方向性」と覚える方が簡単でしょう。

![ブローカーが利用するソケット](images/fig44.eps)

;Note that we connect the cloudbe in each broker to the cloudfe in every other broker, and likewise we connect the statebe in each broker to the statefe in every other broker.

各ブローカーのcloudbeソケットは、他のブローカーのcloudfeソケットに対して接続を行い、これと同様にstatebeソケットで、他のブローカのstatefeソケットに接続を行っています。

### 状態通知の仮実装
;Because each socket flow has its own little traps for the unwary, we will test them in real code one-by-one, rather than try to throw the whole lot into code in one go. When we're happy with each flow, we can put them together into a full program. We'll start with the state flow.

ソケットの通信経路には所々罠が仕掛けられていますので全てのコードが出来上がるのを待たず、ひとつずつテストを行っていきます。
各経路で問題がないことを確認してからプログラム全体で動作確認を行います。
ここでは状態通知経路を実装します。

![状態通知経路](images/fig45.eps)

;Here is how this works in code:

これがコードです。

~~~ {caption="peering1: Prototype state flow in C"}
// Broker peering simulation (part 1)
// Prototypes the state flow

#include "czmq.h"

int main (int argc, char *argv [])
{
    // First argument is this broker's name
    // Other arguments are our peers' names
    //
    if (argc < 2) {
        printf ("syntax: peering1 me {you}…\n");
        return 0;
    }
    char *self = argv [1];
    printf ("I: preparing broker at %s…\n", self);
    srandom ((unsigned) time (NULL));

    zctx_t *ctx = zctx_new ();

    // Bind state backend to endpoint
    void *statebe = zsocket_new (ctx, ZMQ_PUB);
    zsocket_bind (statebe, "ipc://%s-state.ipc", self);

    // Connect statefe to all peers
    void *statefe = zsocket_new (ctx, ZMQ_SUB);
    zsocket_set_subscribe (statefe, "");
    int argn;
    for (argn = 2; argn < argc; argn++) {
        char *peer = argv [argn];
        printf ("I: connecting to state backend at '%s'\n", peer);
        zsocket_connect (statefe, "ipc://%s-state.ipc", peer);
    }
    // The main loop sends out status messages to peers, and collects
    // status messages back from peers. The zmq_poll timeout defines
    // our own heartbeat:

    while (true) {
        // Poll for activity, or 1 second timeout
        zmq_pollitem_t items [] = { { statefe, 0, ZMQ_POLLIN, 0 } };
        int rc = zmq_poll (items, 1, 1000 * ZMQ_POLL_MSEC);
        if (rc == -1)
            break; // Interrupted

        // Handle incoming status messages
        if (items [0].revents & ZMQ_POLLIN) {
            char *peer_name = zstr_recv (statefe);
            char *available = zstr_recv (statefe);
            printf ("%s - %s workers free\n", peer_name, available);
            free (peer_name);
            free (available);
        }
        else {
            // Send random values for worker availability
            zstr_sendm (statebe, self);
            zstr_send (statebe, "%d", randof (10));
        }
    }
    zctx_destroy (&ctx);
    return EXIT_SUCCESS;
}
~~~

;Notes about this code:

このコードの注意点は、

;* Each broker has an identity that we use to construct ipc endpoint names. A real broker would need to work with TCP and a more sophisticated configuration scheme. We'll look at such schemes later in this book, but for now, using generated ipc names lets us ignore the problem of where to get TCP/IP addresses or names.
;* We use a zmq_poll() loop as the core of the program. This processes incoming messages and sends out state messages. We send a state message only if we did not get any incoming messages and we waited for a second. If we send out a state message each time we get one in, we'll get message storms.
;* We use a two-part pub-sub message consisting of sender address and data. Note that we will need to know the address of the publisher in order to send it tasks, and the only way is to send this explicitly as a part of the message.
;* We don't set identities on subscribers because if we did then we'd get outdated state information when connecting to running brokers.
;* We don't set a HWM on the publisher, but if we were using ØMQ v2.x that would be a wise idea.

* 各ブローカーはIPCエンドポイントの名前に利用するIDを持っています。実際にはTCPなどの別の通信方法が利用され、アドレスは設定ファイルなどから読み込むでしょう。これについては本書の後のほうで出てきますので、ひとまずここはIPCを利用します。
* プログラムの主要な部分は`zmq_poll()`ループです。ここで受信したメッセージを処理し、状態情報を配信しています。メッセージを受信せず、1秒が経過した場合にのみ状態情報を配信します。もしも1つのメッセージを受信する度にメッセージを送信した場合、メッセージの嵐が発生するでしょう。
* 状態を通知するためのpub-subメッセージは、送信者のアドレスとデータからなる2つのメッセージフレームで構成します。送信者のアドレスはタスクを送信するために必要なものです。
* 既に動作しているブローカに接続した際に、古い状態情報を取得してしまう可能性があるので、ソケットにサブスクライバーのIDは設定していません。
* ここではHWMを設定していませんが、もしØMQ v2.xを使用しているのであれば設定したほうが良いでしょう。

;We can build this little program and run it three times to simulate three clusters. Let's call them DC1, DC2, and DC3 (the names are arbitrary). We run these three commands, each in a separate window:

このプログラムをビルドしたら3回実行して3つのクラスターをシミュレートします。
何でも構いませんがここではそれぞれのクラスターをDC1, DC2, DC3と呼びます。
3つのターミナルを開いて以下のコマンドを実行してみましょう。

~~~
peering1 DC1 DC2 DC3  #  Start DC1 and connect to DC2 and DC3
peering1 DC2 DC1 DC3  #  Start DC2 and connect to DC1 and DC3
peering1 DC3 DC1 DC2  #  Start DC3 and connect to DC1 and DC2
~~~

;You'll see each cluster report the state of its peers, and after a few seconds they will all happily be printing random numbers once per second. Try this and satisfy yourself that the three brokers all match up and synchronize to per-second state updates.

各クラスターは1秒毎に接続相手の仮の状態情報を出力します。実際にこれを試してみて、3つのブローカーが1秒間隔で状態情報を同期できていることを確認してみましょう。

;In real life, we'd not send out state messages at regular intervals, but rather whenever we had a state change, i.e., whenever a worker becomes available or unavailable. That may seem like a lot of traffic, but state messages are small and we've established that the inter-cluster connections are super fast.

実際には、一定間隔で状態メッセージを送信するのではなく、ワーカーに増減が有った場合などの状態に変更があった場合のみ送信したいと思うかもしれません。
しかしこのメッセージは十分小さく、クラスター間の接続十分速い事は確認しましたので気する必要はないでしょう。

;If we wanted to send state messages at precise intervals, we'd create a child thread and open the statebe socket in that thread. We'd then send irregular state updates to that child thread from our main thread and allow the child thread to conflate them into regular outgoing messages. This is more work than we need here.

もし、状態メッセージ正確な間隔で送信したい場合は子スレッドを生成してstatebeソケットを扱えば良いでしょう。
また、ワーカーの数に更新があった場合にメインスレッドから子スレッドに通知を行い、定期的なメッセージと合わせて送信しても良いでしょう。
これ以上事はここでは取り上げません。

### タスクの通信経路を仮実装
;Let's now prototype at the flow of tasks via the local and cloud sockets. This code pulls requests from clients and then distributes them to local workers and cloud peers on a random basis.

では、localやcloudソケットを経由するタスクの経路を実装してみましょう。
このコードはクライアントから受信したタスクを、ローカルのワーカーや別のクラウドに分散して送信します。ここでは仮にランダムに送信先を決定します。

![タスクの通信経路](images/fig46.eps)

;Before we jump into the code, which is getting a little complex, let's sketch the core routing logic and break it down into a simple yet robust design.

コードが若干複雑になってきているので、まずはルーティングのロジックの整理して設計を掘り下げてみましょう。

;We need two queues, one for requests from local clients and one for requests from cloud clients. One option would be to pull messages off the local and cloud frontends, and pump these onto their respective queues. But this is kind of pointless because ØMQ sockets are queues already. So let's use the ØMQ socket buffers as queues.

ローカルのクライアントと他のクラウドからのリクエストを受け付けるために2つのソケットが必要です。
ローカルとクラウドから受信したメッセージを個別のキューに格納する必要がありますが、ØMQソケットは既にキューになっているので特に配慮する必要はありません。

;This was the technique we used in the load balancing broker, and it worked nicely. We only read from the two frontends when there is somewhere to send the requests. We can always read from the backends, as they give us replies to route back. As long as the backends aren't talking to us, there's no point in even looking at the frontends.

これは負荷分散ブローカーで利用したテクニックですね。
今回は2つフロントエンドソケットから読み込んだメッセージをバックエンドに送信し、2つのバックエンドソケットから読み込んだメッセージをフロントエンドにルーティングします。
また、バックエンドが接続してきていない場合は、フロントエンドのソケットを監視する必要は無いでしょう。

;So our main loop becomes:

メインループはこんな風になります。

;* Poll the backends for activity. When we get a message, it may be "ready" from a worker or it may be a reply. If it's a reply, route back via the local or cloud frontend.
;* If a worker replied, it became available, so we queue it and count it.
;* While there are workers available, take a request, if any, from either frontend and route to a local worker, or randomly, to a cloud peer.

* バックエンドのソケットを監視してメッセージを受信します。これが「準備完了」メッセージであればなにもしません、そうでなければフロントエンドのlocalまたはcloudにルーティングして応答します。
* ワーカーからのメッセージ届けば、そのワーカーは空きになったと言えるのでキューに入れてカウントします。
* フロントエンドからのリクエストを受け付けた時、ワーカーの空きがあれば、ローカルのワーカーか、他のクラウドのどちらかをランダムに選んでルーティングします。

;Randomly sending tasks to a peer broker rather than a worker simulates work distribution across the cluster. It's dumb, but that is fine for this stage.

他のブローカーをワーカーと見なして分散させるのではなく、単純にランダムで選択するというのはあまり賢く無いですが、ここではこれで行きます。

;We use broker identities to route messages between brokers. Each broker has a name that we provide on the command line in this simple prototype. As long as these names don't overlap with the ØMQ-generated UUIDs used for client nodes, we can figure out whether to route a reply back to a client or to a broker.

ブローカーはそれぞれのブローカー間でメッセージのルーティングを行うためにIDを持っており、このIDはコマンドラインで指定しています。
このIDはクライアントノードが生成するUUIDと重複しないように注意して下さい。
もし重複してしまったら、クライアントに返すべき応答がブローカーにルーティングされてしまいます。

;Here is how this works in code. The interesting part starts around the comment "Interesting part".

ここからが実際に動作するコードです。
注目に値する部分は、「ここからが面白い」とコメントで書いてあります。

~~~ {caption="peering2: Prototype local and cloud flow in C"}
// Broker peering simulation (part 2)
// Prototypes the request-reply flow

#include "czmq.h"
#define NBR_CLIENTS 10
#define NBR_WORKERS 3
#define WORKER_READY "\001" // Signals worker is ready

// Our own name; in practice this would be configured per node
static char *self;

// The client task does a request-reply dialog using a standard
// synchronous REQ socket:

static void *
client_task (void *args)
{
    zctx_t *ctx = zctx_new ();
    void *client = zsocket_new (ctx, ZMQ_REQ);
    zsocket_connect (client, "ipc://%s-localfe.ipc", self);

    while (true) {
        // Send request, get reply
        zstr_send (client, "HELLO");
        char *reply = zstr_recv (client);
        if (!reply)
            break; // Interrupted
        printf ("Client: %s\n", reply);
        free (reply);
        sleep (1);
    }
    zctx_destroy (&ctx);
    return NULL;
}

// The worker task plugs into the load-balancer using a REQ
// socket:

static void *
worker_task (void *args)
{
    zctx_t *ctx = zctx_new ();
    void *worker = zsocket_new (ctx, ZMQ_REQ);
    zsocket_connect (worker, "ipc://%s-localbe.ipc", self);

    // Tell broker we're ready for work
    zframe_t *frame = zframe_new (WORKER_READY, 1);
    zframe_send (&frame, worker, 0);

    // Process messages as they arrive
    while (true) {
        zmsg_t *msg = zmsg_recv (worker);
        if (!msg)
            break; // Interrupted

        zframe_print (zmsg_last (msg), "Worker: ");
        zframe_reset (zmsg_last (msg), "OK", 2);
        zmsg_send (&msg, worker);
    }
    zctx_destroy (&ctx);
    return NULL;
}

// The main task begins by setting-up its frontend and backend sockets
// and then starting its client and worker tasks:

int main (int argc, char *argv [])
{
    // First argument is this broker's name
    // Other arguments are our peers' names
    //
    if (argc < 2) {
        printf ("syntax: peering2 me {you}…\n");
        return 0;
    }
    self = argv [1];
    printf ("I: preparing broker at %s…\n", self);
    srandom ((unsigned) time (NULL));

    zctx_t *ctx = zctx_new ();

    // Bind cloud frontend to endpoint
    void *cloudfe = zsocket_new (ctx, ZMQ_ROUTER);
    zsocket_set_identity (cloudfe, self);
    zsocket_bind (cloudfe, "ipc://%s-cloud.ipc", self);

    // Connect cloud backend to all peers
    void *cloudbe = zsocket_new (ctx, ZMQ_ROUTER);
    zsocket_set_identity (cloudbe, self);
    int argn;
    for (argn = 2; argn < argc; argn++) {
        char *peer = argv [argn];
        printf ("I: connecting to cloud frontend at '%s'\n", peer);
        zsocket_connect (cloudbe, "ipc://%s-cloud.ipc", peer);
    }
    // Prepare local frontend and backend
    void *localfe = zsocket_new (ctx, ZMQ_ROUTER);
    zsocket_bind (localfe, "ipc://%s-localfe.ipc", self);
    void *localbe = zsocket_new (ctx, ZMQ_ROUTER);
    zsocket_bind (localbe, "ipc://%s-localbe.ipc", self);

    // Get user to tell us when we can start…
    printf ("Press Enter when all brokers are started: ");
    getchar ();

    // Start local workers
    int worker_nbr;
    for (worker_nbr = 0; worker_nbr < NBR_WORKERS; worker_nbr++)
        zthread_new (worker_task, NULL);

    // Start local clients
    int client_nbr;
    for (client_nbr = 0; client_nbr < NBR_CLIENTS; client_nbr++)
        zthread_new (client_task, NULL);

    // ここからが面白い
    // Here, we handle the request-reply flow. We're using load-balancing
    // to poll workers at all times, and clients only when there are one //
    // or more workers available.//

    // Least recently used queue of available workers
    int capacity = 0;
    zlist_t *workers = zlist_new ();

    while (true) {
        // First, route any waiting replies from workers
        zmq_pollitem_t backends [] = {
            { localbe, 0, ZMQ_POLLIN, 0 },
            { cloudbe, 0, ZMQ_POLLIN, 0 }
        };
        // If we have no workers, wait indefinitely
        int rc = zmq_poll (backends, 2,
        capacity? 1000 * ZMQ_POLL_MSEC: -1);
        if (rc == -1)
        break; // Interrupted

        // Handle reply from local worker
        zmsg_t *msg = NULL;
        if (backends [0].revents & ZMQ_POLLIN) {
            msg = zmsg_recv (localbe);
            if (!msg)
                break; // Interrupted
            zframe_t *identity = zmsg_unwrap (msg);
            zlist_append (workers, identity);
            capacity++;

         // If it's READY, don't route the message any further
         zframe_t *frame = zmsg_first (msg);
         if (memcmp (zframe_data (frame), WORKER_READY, 1) == 0)
             zmsg_destroy (&msg);
    }
    // Or handle reply from peer broker
    else
    if (backends [1].revents & ZMQ_POLLIN) {
        msg = zmsg_recv (cloudbe);
        if (!msg)
            break; // Interrupted
        // We don't use peer broker identity for anything
        zframe_t *identity = zmsg_unwrap (msg);
        zframe_destroy (&identity);
    }
    // Route reply to cloud if it's addressed to a broker
    for (argn = 2; msg && argn < argc; argn++) {
        char *data = (char *) zframe_data (zmsg_first (msg));
        size_t size = zframe_size (zmsg_first (msg));
        if (size == strlen (argv [argn])
            && memcmp (data, argv [argn], size) == 0)
            zmsg_send (&msg, cloudfe);
    }
    // Route reply to client if we still need to
    if (msg)
        zmsg_send (&msg, localfe);

    // Now we route as many client requests as we have worker capacity
    // for. We may reroute requests from our local frontend, but not from //
    // the cloud frontend. We reroute randomly now, just to test things
    // out. In the next version, we'll do this properly by calculating
    // cloud capacity://

    while (capacity) {
        zmq_pollitem_t frontends [] = {
            { localfe, 0, ZMQ_POLLIN, 0 },
            { cloudfe, 0, ZMQ_POLLIN, 0 }
        };
        rc = zmq_poll (frontends, 2, 0);
        assert (rc >= 0);
        int reroutable = 0;
        // We'll do peer brokers first, to prevent starvation
        if (frontends [1].revents & ZMQ_POLLIN) {
            msg = zmsg_recv (cloudfe);
            reroutable = 0;
        }
        else
        if (frontends [0].revents & ZMQ_POLLIN) {
            msg = zmsg_recv (localfe);
            reroutable = 1;
        }
        else
            break; // No work, go back to backends

        // If reroutable, send to cloud 20% of the time
        // Here we'd normally use cloud status information
        //
        if (reroutable && argc > 2 && randof (5) == 0) {
            // Route to random broker peer
            int peer = randof (argc - 2) + 2;
            zmsg_pushmem (msg, argv [peer], strlen (argv [peer]));
            zmsg_send (&msg, cloudbe);
        }
        else {
            zframe_t *frame = (zframe_t *) zlist_pop (workers);
            zmsg_wrap (msg, frame);
            zmsg_send (&msg, localbe);
            capacity--;
        }
    }
}
~~~

;Run this by, for instance, starting two instances of the broker in two windows:

これを試すには、ターミナルを2つ開いて2つのインスタンスを起動して下さい。

~~~
peering2 me you
peering2 you me
~~~

;Some comments on this code:

少し解説しておくと、

;* In the C code at least, using the zmsg class makes life much easier, and our code much shorter. It's obviously an abstraction that works. If you build ØMQ applications in C, you should use CZMQ.
;* Because we're not getting any state information from peers, we naively assume they are running. The code prompts you to confirm when you've started all the brokers. In the real case, we'd not send anything to brokers who had not told us they exist.

* C言語の場合、機能を抽象化したzmsg_関数を利用することで短くて簡潔なコードになります。これをビルドするには、CZMQライブラリとリンクする必要があります。
* ピアブローカーからの状態情報が送られて来ない場合でも、普通に動作していると仮定してしまいますので、コードの最初で全てのブローカーが起動しているかどうかを確認しています。実際にはブローカーが何も言わなくなった時は、タスクを送信しないようにしてやると良いでしょう。

;You can satisfy yourself that the code works by watching it run forever. If there were any misrouted messages, clients would end up blocking, and the brokers would stop printing trace information. You can prove that by killing either of the brokers. The other broker tries to send requests to the cloud, and one-by-one its clients block, waiting for an answer.

あなたは動き続けているコードを眺めて満足するでしょう。
もしもメッセージが誤った経路で流れると、クライアントは停止してブローカーはトレース情報を出力しなくなるでしょう。
クライアントは応答が返ってくるまで待ち続けてしまいますので、こうなった場合はクライアントとブローカーを再起動するしかありません。

### プログラムの結合
;Let's put this together into a single package. As before, we'll run an entire cluster as one process. We're going to take the two previous examples and merge them into one properly working design that lets you simulate any number of clusters.

それではこれまでの仮実装のコードをひとつにまとめてみましょう。
以前にも述べた通り、ここでは1クラスターの全てを1プロセスで実現します。
そこで先程の2つのコードを合わせることで、クラスターをシミュレート出来るようになります。

;This code is the size of both previous prototypes together, at 270 LoC. That's pretty good for a simulation of a cluster that includes clients and workers and cloud workload distribution. Here is the code:

先程の仮実装を合わせると、コードサイズは約270行程度になります。
これはクライアントとワーカーを含む負荷分散クラスターを上手くシミュレートしています。
コードはこちらです。

~~~ {caption="peering3: Full cluster simulation in C"}
//  Broker peering simulation (part 3)
//  Prototypes the full flow of status and tasks

#include "czmq.h"
#define NBR_CLIENTS 10
#define NBR_WORKERS 5
#define WORKER_READY   "\001"      //  Signals worker is ready

//  Our own name; in practice, this would be configured per node
static char *self;

//  .split client task
//  This is the client task. It issues a burst of requests and then
//  sleeps for a few seconds. This simulates sporadic activity; when
//  a number of clients are active at once, the local workers should
//  be overloaded. The client uses a REQ socket for requests and also
//  pushes statistics to the monitor socket:

static void *
client_task (void *args)
{
    zctx_t *ctx = zctx_new ();
    void *client = zsocket_new (ctx, ZMQ_REQ);
    zsocket_connect (client, "ipc://%s-localfe.ipc", self);
    void *monitor = zsocket_new (ctx, ZMQ_PUSH);
    zsocket_connect (monitor, "ipc://%s-monitor.ipc", self);

    while (true) {
        sleep (randof (5));
        int burst = randof (15);
        while (burst--) {
            char task_id [5];
            sprintf (task_id, "%04X", randof (0x10000));

            //  Send request with random hex ID
            zstr_send (client, task_id);

            //  Wait max ten seconds for a reply, then complain
            zmq_pollitem_t pollset [1] = { { client, 0, ZMQ_POLLIN, 0 } };
            int rc = zmq_poll (pollset, 1, 10 * 1000 * ZMQ_POLL_MSEC);
            if (rc == -1)
                break;          //  Interrupted

            if (pollset [0].revents & ZMQ_POLLIN) {
                char *reply = zstr_recv (client);
                if (!reply)
                    break;              //  Interrupted
                //  Worker is supposed to answer us with our task id
                assert (streq (reply, task_id));
                zstr_send (monitor, "%s", reply);
                free (reply);
            }
            else {
                zstr_send (monitor,
                    "E: CLIENT EXIT - lost task %s", task_id);
                return NULL;
            }
        }
    }
    zctx_destroy (&ctx);
    return NULL;
}

//  .split worker task
//  This is the worker task, which uses a REQ socket to plug into the
//  load-balancer. It's the same stub worker task that you've seen in 
//  other examples:

static void *
worker_task (void *args)
{
    zctx_t *ctx = zctx_new ();
    void *worker = zsocket_new (ctx, ZMQ_REQ);
    zsocket_connect (worker, "ipc://%s-localbe.ipc", self);

    //  Tell broker we're ready for work
    zframe_t *frame = zframe_new (WORKER_READY, 1);
    zframe_send (&frame, worker, 0);

    //  Process messages as they arrive
    while (true) {
        zmsg_t *msg = zmsg_recv (worker);
        if (!msg)
            break;              //  Interrupted

        //  Workers are busy for 0/1 seconds
        sleep (randof (2));
        zmsg_send (&msg, worker);
    }
    zctx_destroy (&ctx);
    return NULL;
}

//  .split main task
//  The main task begins by setting up all its sockets. The local frontend
//  talks to clients, and our local backend talks to workers. The cloud
//  frontend talks to peer brokers as if they were clients, and the cloud
//  backend talks to peer brokers as if they were workers. The state
//  backend publishes regular state messages, and the state frontend
//  subscribes to all state backends to collect these messages. Finally,
//  we use a PULL monitor socket to collect printable messages from tasks:

int main (int argc, char *argv [])
{
    //  First argument is this broker's name
    //  Other arguments are our peers' names
    if (argc < 2) {
        printf ("syntax: peering3 me {you}...\n");
        return 0;
    }
    self = argv [1];
    printf ("I: preparing broker at %s...\n", self);
    srandom ((unsigned) time (NULL));

    //  Prepare local frontend and backend
    zctx_t *ctx = zctx_new ();
    void *localfe = zsocket_new (ctx, ZMQ_ROUTER);
    zsocket_bind (localfe, "ipc://%s-localfe.ipc", self);

    void *localbe = zsocket_new (ctx, ZMQ_ROUTER);
    zsocket_bind (localbe, "ipc://%s-localbe.ipc", self);

    //  Bind cloud frontend to endpoint
    void *cloudfe = zsocket_new (ctx, ZMQ_ROUTER);
    zsocket_set_identity (cloudfe, self);
    zsocket_bind (cloudfe, "ipc://%s-cloud.ipc", self);
    
    //  Connect cloud backend to all peers
    void *cloudbe = zsocket_new (ctx, ZMQ_ROUTER);
    zsocket_set_identity (cloudbe, self);
    int argn;
    for (argn = 2; argn < argc; argn++) {
        char *peer = argv [argn];
        printf ("I: connecting to cloud frontend at '%s'\n", peer);
        zsocket_connect (cloudbe, "ipc://%s-cloud.ipc", peer);
    }
    //  Bind state backend to endpoint
    void *statebe = zsocket_new (ctx, ZMQ_PUB);
    zsocket_bind (statebe, "ipc://%s-state.ipc", self);

    //  Connect state frontend to all peers
    void *statefe = zsocket_new (ctx, ZMQ_SUB);
    zsocket_set_subscribe (statefe, "");
    for (argn = 2; argn < argc; argn++) {
        char *peer = argv [argn];
        printf ("I: connecting to state backend at '%s'\n", peer);
        zsocket_connect (statefe, "ipc://%s-state.ipc", peer);
    }
    //  Prepare monitor socket
    void *monitor = zsocket_new (ctx, ZMQ_PULL);
    zsocket_bind (monitor, "ipc://%s-monitor.ipc", self);

    //  .split start child tasks
    //  After binding and connecting all our sockets, we start our child
    //  tasks - workers and clients:

    int worker_nbr;
    for (worker_nbr = 0; worker_nbr < NBR_WORKERS; worker_nbr++)
        zthread_new (worker_task, NULL);

    //  Start local clients
    int client_nbr;
    for (client_nbr = 0; client_nbr < NBR_CLIENTS; client_nbr++)
        zthread_new (client_task, NULL);

    //  Queue of available workers
    int local_capacity = 0;
    int cloud_capacity = 0;
    zlist_t *workers = zlist_new ();

    //  .split main loop
    //  The main loop has two parts. First, we poll workers and our two service
    //  sockets (statefe and monitor), in any case. If we have no ready workers,
    //  then there's no point in looking at incoming requests. These can remain
    //  on their internal 0MQ queues:

    while (true) {
        zmq_pollitem_t primary [] = {
            { localbe, 0, ZMQ_POLLIN, 0 },
            { cloudbe, 0, ZMQ_POLLIN, 0 },
            { statefe, 0, ZMQ_POLLIN, 0 },
            { monitor, 0, ZMQ_POLLIN, 0 }
        };
        //  If we have no workers ready, wait indefinitely
        int rc = zmq_poll (primary, 4,
            local_capacity? 1000 * ZMQ_POLL_MSEC: -1);
        if (rc == -1)
            break;              //  Interrupted

        //  Track if capacity changes during this iteration
        int previous = local_capacity;
        zmsg_t *msg = NULL;     //  Reply from local worker

        if (primary [0].revents & ZMQ_POLLIN) {
            msg = zmsg_recv (localbe);
            if (!msg)
                break;          //  Interrupted
            zframe_t *identity = zmsg_unwrap (msg);
            zlist_append (workers, identity);
            local_capacity++;

            //  If it's READY, don't route the message any further
            zframe_t *frame = zmsg_first (msg);
            if (memcmp (zframe_data (frame), WORKER_READY, 1) == 0)
                zmsg_destroy (&msg);
        }
        //  Or handle reply from peer broker
        else
        if (primary [1].revents & ZMQ_POLLIN) {
            msg = zmsg_recv (cloudbe);
            if (!msg)
                break;          //  Interrupted
            //  We don't use peer broker identity for anything
            zframe_t *identity = zmsg_unwrap (msg);
            zframe_destroy (&identity);
        }
        //  Route reply to cloud if it's addressed to a broker
        for (argn = 2; msg && argn < argc; argn++) {
            char *data = (char *) zframe_data (zmsg_first (msg));
            size_t size = zframe_size (zmsg_first (msg));
            if (size == strlen (argv [argn])
            &&  memcmp (data, argv [argn], size) == 0)
                zmsg_send (&msg, cloudfe);
        }
        //  Route reply to client if we still need to
        if (msg)
            zmsg_send (&msg, localfe);

        //  .split handle state messages
        //  If we have input messages on our statefe or monitor sockets, we
        //  can process these immediately:

        if (primary [2].revents & ZMQ_POLLIN) {
            char *peer = zstr_recv (statefe);
            char *status = zstr_recv (statefe);
            cloud_capacity = atoi (status);
            free (peer);
            free (status);
        }
        if (primary [3].revents & ZMQ_POLLIN) {
            char *status = zstr_recv (monitor);
            printf ("%s\n", status);
            free (status);
        }
        //  .split route client requests
        //  Now route as many clients requests as we can handle. If we have
        //  local capacity, we poll both localfe and cloudfe. If we have cloud
        //  capacity only, we poll just localfe. We route any request locally
        //  if we can, else we route to the cloud.

        while (local_capacity + cloud_capacity) {
            zmq_pollitem_t secondary [] = {
                { localfe, 0, ZMQ_POLLIN, 0 },
                { cloudfe, 0, ZMQ_POLLIN, 0 }
            };
            if (local_capacity)
                rc = zmq_poll (secondary, 2, 0);
            else
                rc = zmq_poll (secondary, 1, 0);
            assert (rc >= 0);

            if (secondary [0].revents & ZMQ_POLLIN)
                msg = zmsg_recv (localfe);
            else
            if (secondary [1].revents & ZMQ_POLLIN)
                msg = zmsg_recv (cloudfe);
            else
                break;      //  No work, go back to primary

            if (local_capacity) {
                zframe_t *frame = (zframe_t *) zlist_pop (workers);
                zmsg_wrap (msg, frame);
                zmsg_send (&msg, localbe);
                local_capacity--;
            }
            else {
                //  Route to random broker peer
                int peer = randof (argc - 2) + 2;
                zmsg_pushmem (msg, argv [peer], strlen (argv [peer]));
                zmsg_send (&msg, cloudbe);
            }
        }
        //  .split broadcast capacity
        //  We broadcast capacity messages to other peers; to reduce chatter,
        //  we do this only if our capacity changed.

        if (local_capacity != previous) {
            //  We stick our own identity onto the envelope
            zstr_sendm (statebe, self);
            //  Broadcast new capacity
            zstr_send (statebe, "%d", local_capacity);
        }
    }
    //  When we're done, clean up properly
    while (zlist_size (workers)) {
        zframe_t *frame = (zframe_t *) zlist_pop (workers);
        zframe_destroy (&frame);
    }
    zlist_destroy (&workers);
    zctx_destroy (&ctx);
    return EXIT_SUCCESS;
}
~~~

;It's a nontrivial program and took about a day to get working. These are the highlights:

これはそこそこ大きなプログラムですので実装するのに1日かかりました。
以下に要点をまとめます。

;* The client threads detect and report a failed request. They do this by polling for a response and if none arrives after a while (10 seconds), printing an error message.
;* Client threads don't print directly, but instead send a message to a monitor socket (PUSH) that the main loop collects (PULL) and prints off. This is the first case we've seen of using ØMQ sockets for monitoring and logging; this is a big use case that we'll come back to later.
;* Clients simulate varying loads to get the cluster 100% at random moments, so that tasks are shifted over to the cloud. The number of clients and workers, and delays in the client and worker threads control this. Feel free to play with them to see if you can make a more realistic simulation.
;* The main loop uses two pollsets. It could in fact use three: information, backends, and frontends. As in the earlier prototype, there is no point in taking a frontend message if there is no backend capacity.

* クライアントスレッドはリクエストの失敗を検知して報告します。これはレスポンスが返ってくるまでの間ソケットを監視して、10秒間何も返ってこなければエラーと判断します。
* クライアントスレッドは直接表示を行わず、PUSHソケットでモニター用のPULLソケットに対してメッセージを送信し、ブローカーと同じメインスレッドで出力を行います。ここで初めてØMQソケットをモニタリングとログ出力に利用しましたが、この使い方は重要ですので後で詳しく説明します。
* クライアントは様々な負荷をシミュレートし、そのタスクはクラウドに移されます。シミュレートする負荷は、クライアントとワーカーの数および遅延時間で制御出来ます。このプログラムを実行し、より現実的な用途に適用できるかどうかを確認してみて下さい。
* メインループでは2つのzmq_pollitem_t構造体を利用しています。実際には3つに分けても良いでしょう。バックエンド容量が無い時にフロントエンドを監視しても意味が無いので、このサンプルコードでは2つに分けています。

;These are some of the problems that arose during development of this program:

このプログラムを開発するにあたって発生した問題をまとめると、

;* Clients would freeze, due to requests or replies getting lost somewhere. Recall that the ROUTER socket drops messages it can't route. The first tactic here was to modify the client thread to detect and report such problems. Secondly, I put zmsg_dump() calls after every receive and before every send in the main loop, until the origin of the problems was clear.
;* The main loop was mistakenly reading from more than one ready socket. This caused the first message to be lost. I fixed that by reading only from the first ready socket.
;* The zmsg class was not properly encoding UUIDs as C strings. This caused UUIDs that contain 0 bytes to be corrupted. I fixed that by modifying zmsg to encode UUIDs as printable hex strings.

* クライアントはリクエストや応答が迷子になってしまうとフリーズしてしまう問題がありました。ROUTERソケットはルーティング出来ないメッセージを捨ててしまうからです。最初に行った対策はクライアントスレッドでこれを検知して問題を報告するようにしました。そして、メッセージの受信を行った直後に`zmsg_dump()`を呼び出すようにしました。これで問題の所在が明らかになります。
* ブローカーのメインループで複数のソケットにメッセージが届いた場合、最初のメッセージを取りこぼすという問題がありました。これは最初に準備が出来たソケットからメッセージを受信する様にして修正しました。

;This simulation does not detect disappearance of a cloud peer. If you start several peers and stop one, and it was broadcasting capacity to the others, they will continue to send it work even if it's gone. You can try this, and you will get clients that complain of lost requests. The solution is twofold: first, only keep the capacity information for a short time so that if a peer does disappear, its capacity is quickly set to zero. Second, add reliability to the request-reply chain. We'll look at reliability in the next chapter.

このシミュレーションはクラウドの停止を検知しません。複数のクラウドを開始してひとつを停止した場合、一度でも処理容量を通知していれば他のクラウドはメッセージを送り続け、クライアントのタスクは消失していまいます。これは簡単にリクエストの消失状態を再現することが出来ます。解決方法は2つあります。1つ目は、クラウドからの処理容量の通知が届かなくなり、一定の時間が経ったら処理容量を0に設定することです。もうひとつの方法は信頼性のあるリクエスト・応答モデルを構築することです。これについては次の章で説明します。

