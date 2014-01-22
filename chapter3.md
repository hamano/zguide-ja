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
この組み合わせはエラーからの復旧に関連していますので、後ほどの「Chapter 4 - Reliable Request-Reply Patterns」でも出てきます。

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
このコードでは、メッセージフレームを追跡し易くする為に、クライアントとワーカーのIDを設定しています。
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
* zmq_poll()の単純化。pollループは単純ですがやや不格好です。大抵の場合、タイマーを設定して、ソケットから読み出すという単純なコードになりがちです。この単純化によって余計なな繰り返し作業を削減します。
* Ctrl-Cを適切に処理する。既に割り込みを処理する方法を見てきましたが、これは全てのアプリケーションで必要とされる処理です。

### CZMQ高級API

## 非同期クライアント・サーバーパターン

## Worked Example: Inter-Broker Routing
### Establishing the Details
### Architecture of a Single Cluster
### Scaling to Multiple Clusters
### Federation Versus Peering
### The Naming Ceremony
### Prototyping the State Flow
### Prototyping the Local and Cloud Flows
### Putting it All Together
