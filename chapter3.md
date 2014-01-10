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
これは第4章の「Reliable Request-Reply Patterns」で詳しく見ていきます。

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

;*These are the legal combinations:

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
第4章「Reliable Request-Reply Patterns」ではこれを利用したフリーランス・パターンをという例を見ていきます。
また、第8章「A Framework for Distributed Computing」ではP2P機能を設計するする為のDEALER対ROUTER通信の代替としてとして紹介します。

### 不正な組み合わせ

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
