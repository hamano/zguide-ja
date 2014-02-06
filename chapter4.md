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
ビーチハウスの裏側に高級プールを作りましょう。

## 信頼性の設計
;So to make things brutally simple, reliability is "keeping things working properly when code freezes or crashes", a situation we'll shorten to "dies". However, the things we want to keep working properly are more complex than just messages. We need to take each core ØMQ messaging pattern and see how to make it work (if we can) even when code dies.

とても単純な事なのですが、信頼性とは「コードがフリーズしたりクラッシュしてしまい、いわゆる「落ちた」という状況であっても、正しく動作し続けること」なのです。
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
* 複数のクライアントがブローカーなどのプロキシーを経由して複数のワーカーと通信する場合。これはサービス指向のトランザクションを処理する場合などに使われます。考えられる障害はワーカーの再起動やクラッシュ、ワーカーのビジーループ、ワーカーの高負荷、キューのクラッシュや再起動、ネットワークの切断です。
* 複数のクライアントが複数のサーバーとプロキシーを経由せずに通信する場合。名前解決などによるサービスの分散方法です。考えられる障害はサービスのビジーループ、サービスの高負荷、ネットワークの切断です。

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

~~~ {caption="lpclient: Lazy Pirate client in C"}
//  Lazy Pirate client
//  Use zmq_poll to do a safe request-reply
//  To run, start lpserver and then randomly kill/restart it

#include "czmq.h"
#define REQUEST_TIMEOUT     2500    //  msecs, (> 1000!)
#define REQUEST_RETRIES     3       //  Before we abandon
#define SERVER_ENDPOINT     "tcp://localhost:5555"

int main (void)
{
    zctx_t *ctx = zctx_new ();
    printf ("I: connecting to server...\n");
    void *client = zsocket_new (ctx, ZMQ_REQ);
    assert (client);
    zsocket_connect (client, SERVER_ENDPOINT);

    int sequence = 0;
    int retries_left = REQUEST_RETRIES;
    while (retries_left && !zctx_interrupted) {
        //  We send a request, then we work to get a reply
        char request [10];
        sprintf (request, "%d", ++sequence);
        zstr_send (client, request);

        int expect_reply = 1;
        while (expect_reply) {
            //  Poll socket for a reply, with timeout
            zmq_pollitem_t items [] = { { client, 0, ZMQ_POLLIN, 0 } };
            int rc = zmq_poll (items, 1, REQUEST_TIMEOUT * ZMQ_POLL_MSEC);
            if (rc == -1)
                break;          //  Interrupted

            //  .split process server reply
            //  Here we process a server reply and exit our loop if the
            //  reply is valid. If we didn't a reply we close the client
            //  socket and resend the request. We try a number of times
            //  before finally abandoning:
            
            if (items [0].revents & ZMQ_POLLIN) {
                //  We got a reply from the server, must match sequence
                char *reply = zstr_recv (client);
                if (!reply)
                    break;      //  Interrupted
                if (atoi (reply) == sequence) {
                    printf ("I: server replied OK (%s)\n", reply);
                    retries_left = REQUEST_RETRIES;
                    expect_reply = 0;
                }
                else
                    printf ("E: malformed reply from server: %s\n",
                        reply);

                free (reply);
            }
            else
            if (--retries_left == 0) {
                printf ("E: server seems to be offline, abandoning\n");
                break;
            }
            else {
                printf ("W: no response from server, retrying...\n");
                //  Old socket is confused; close it and open a new one
                zsocket_destroy (ctx, client);
                printf ("I: reconnecting to server...\n");
                client = zsocket_new (ctx, ZMQ_REQ);
                zsocket_connect (client, SERVER_ENDPOINT);
                //  Send request again, on new socket
                zstr_send (client, request);
            }
        }
    }
    zctx_destroy (&ctx);
    return 0;
}
~~~

;Run this together with the matching server:
こちらのサーバーも実行してください。

~~~ {caption="lpserver: Lazy Pirate server in C"}
//  Lazy Pirate server
//  Binds REQ socket to tcp://*:5555
//  Like hwserver except:
//   - echoes request as-is
//   - randomly runs slowly, or exits to simulate a crash.

#include "zhelpers.h"

int main (void)
{
    srandom ((unsigned) time (NULL));

    void *context = zmq_ctx_new ();
    void *server = zmq_socket (context, ZMQ_REP);
    zmq_bind (server, "tcp://*:5555");

    int cycles = 0;
    while (1) {
        char *request = s_recv (server);
        cycles++;

        //  Simulate various problems, after a few cycles
        if (cycles > 3 && randof (3) == 0) {
            printf ("I: simulating a crash\n");
            break;
        }
        else
        if (cycles > 3 && randof (3) == 0) {
            printf ("I: simulating CPU overload\n");
            sleep (2);
        }
        printf ("I: normal request (%s)\n", request);
        sleep (1);              //  Do some heavy work
        s_send (server, request);
        free (request);
    }
    zmq_close (server);
    zmq_ctx_destroy (context);
    return 0;
}
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

## 信頼性のあるキューイング (Simple Pirate Pattern)
;Our second approach extends the Lazy Pirate pattern with a queue proxy that lets us talk, transparently, to multiple servers, which we can more accurately call "workers". We'll develop this in stages, starting with a minimal working model, the Simple Pirate pattern.

2番目に紹介する方法は複数のサーバーと透過的に通信を行うキュープロキシーを用いてものぐさ海賊パターンを拡張します。
まずは単純な海賊パターンが最低限動作する小さなモデルで実装していきます。

;In all these Pirate patterns, workers are stateless. If the application requires some shared state, such as a shared database, we don't know about it as we design our messaging framework. Having a queue proxy means workers can come and go without clients knowing anything about it. If one worker dies, another takes over. This is a nice, simple topology with only one real weakness, namely the central queue itself, which can become a problem to manage, and a single point of failure.

全ての海賊パターンにおいて、ワーカーはステートレスで動作します。
もしアプリケーションがデーターベースなどを利用して状態を共有したい場合でもメッセージングフレームワークはこれに関知しません。
キュープロキシーはクライアントについて何も知らずにやってくるメッセージをそのまま転送するだけの役割を持っています。
こうした方がワーカーが落ちてしまった場合でも別のワーカーにメッセージを渡すだけで良いので都合が良いのです。
これは単純でなかなか良いトポロジーですが中央キューが単一故障点になってしまうという欠点があります。

![単純な海賊パターン](images/fig48.eps)

;The basis for the queue proxy is the load balancing broker from Chapter 3 - Advanced Request-Reply Patterns. What is the very minimum we need to do to handle dead or blocked workers? Turns out, it's surprisingly little. We already have a retry mechanism in the client. So using the load balancing pattern will work pretty well. This fits with ØMQ's philosophy that we can extend a peer-to-peer pattern like request-reply by plugging naive proxies in the middle.

負荷分散を行うキュープロキシーについては第3章「リクエスト・応答パターンの応用」で見てきました。
ワーカーが落ちたりブロックしたりする障害に対して最低限どの様な対応を行う必要があるでしょうか?
クライアントには再試行が実装されていますので、負荷分散パターンが効果的に機能します。
;[TODO]
;これはまさしくØMQの哲学に適合し、中間にプロキシーを介する事でP2Pパターンに拡張することが可能です。

;We don't need a special client; we're still using the Lazy Pirate client. Here is the queue, which is identical to the main task of the load balancing broker:

これには特別なクライアントは必要ありません。
先程のものぐさ海賊パターンと同じクライアントを利用します。
こちらが負荷分散ブローカーと同等の機能を持ったキュープロキシーのコードです。

~~~ {caption="spqueue: Simple Pirate queue in C"}
//  Simple Pirate broker
//  This is identical to load-balancing pattern, with no reliability
//  mechanisms. It depends on the client for recovery. Runs forever.

#include "czmq.h"
#define WORKER_READY   "\001"      //  Signals worker is ready

int main (void)
{
    zctx_t *ctx = zctx_new ();
    void *frontend = zsocket_new (ctx, ZMQ_ROUTER);
    void *backend = zsocket_new (ctx, ZMQ_ROUTER);
    zsocket_bind (frontend, "tcp://*:5555");    //  For clients
    zsocket_bind (backend,  "tcp://*:5556");    //  For workers

    //  Queue of available workers
    zlist_t *workers = zlist_new ();
    
    //  The body of this example is exactly the same as lbbroker2.
    //  .skip
    while (true) {
        zmq_pollitem_t items [] = {
            { backend,  0, ZMQ_POLLIN, 0 },
            { frontend, 0, ZMQ_POLLIN, 0 }
        };
        //  Poll frontend only if we have available workers
        int rc = zmq_poll (items, zlist_size (workers)? 2: 1, -1);
        if (rc == -1)
            break;              //  Interrupted

        //  Handle worker activity on backend
        if (items [0].revents & ZMQ_POLLIN) {
            //  Use worker identity for load-balancing
            zmsg_t *msg = zmsg_recv (backend);
            if (!msg)
                break;          //  Interrupted
            zframe_t *identity = zmsg_unwrap (msg);
            zlist_append (workers, identity);

            //  Forward message to client if it's not a READY
            zframe_t *frame = zmsg_first (msg);
            if (memcmp (zframe_data (frame), WORKER_READY, 1) == 0)
                zmsg_destroy (&msg);
            else
                zmsg_send (&msg, frontend);
        }
        if (items [1].revents & ZMQ_POLLIN) {
            //  Get client request, route to first available worker
            zmsg_t *msg = zmsg_recv (frontend);
            if (msg) {
                zmsg_wrap (msg, (zframe_t *) zlist_pop (workers));
                zmsg_send (&msg, backend);
            }
        }
    }
    //  When we're done, clean up properly
    while (zlist_size (workers)) {
        zframe_t *frame = (zframe_t *) zlist_pop (workers);
        zframe_destroy (&frame);
    }
    zlist_destroy (&workers);
    zctx_destroy (&ctx);
    return 0;
    //  .until
}
~~~

;Here is the worker, which takes the Lazy Pirate server and adapts it for the load balancing pattern (using the REQ "ready" signaling):

こちらがワーカーのコードです。
ものぐさ海賊パターンのサーバーと同じような仕組みを負荷分散ブローカーに組み込んでいます。

~~~ {caption="spworker: Simple Pirate worker in C"}
//  Simple Pirate worker
//  Connects REQ socket to tcp://*:5556
//  Implements worker part of load-balancing

#include "czmq.h"
#define WORKER_READY   "\001"      //  Signals worker is ready

int main (void)
{
    zctx_t *ctx = zctx_new ();
    void *worker = zsocket_new (ctx, ZMQ_REQ);

    //  Set random identity to make tracing easier
    srandom ((unsigned) time (NULL));
    char identity [10];
    sprintf (identity, "%04X-%04X", randof (0x10000), randof (0x10000));
    zmq_setsockopt (worker, ZMQ_IDENTITY, identity, strlen (identity));
    zsocket_connect (worker, "tcp://localhost:5556");

    //  Tell broker we're ready for work
    printf ("I: (%s) worker ready\n", identity);
    zframe_t *frame = zframe_new (WORKER_READY, 1);
    zframe_send (&frame, worker, 0);

    int cycles = 0;
    while (true) {
        zmsg_t *msg = zmsg_recv (worker);
        if (!msg)
            break;              //  Interrupted

        //  Simulate various problems, after a few cycles
        cycles++;
        if (cycles > 3 && randof (5) == 0) {
            printf ("I: (%s) simulating a crash\n", identity);
            zmsg_destroy (&msg);
            break;
        }
        else
        if (cycles > 3 && randof (5) == 0) {
            printf ("I: (%s) simulating CPU overload\n", identity);
            sleep (3);
            if (zctx_interrupted)
                break;
        }
        printf ("I: (%s) normal reply\n", identity);
        sleep (1);              //  Do some heavy work
        zmsg_send (&msg, worker);
    }
    zctx_destroy (&ctx);
    return 0;
}
~~~

;To test this, start a handful of workers, a Lazy Pirate client, and the queue, in any order. You'll see that the workers eventually all crash and burn, and the client retries and then gives up. The queue never stops, and you can restart workers and clients ad nauseam. This model works with any number of clients and workers.

これをテストするには幾つかのワーカーとものぐさ海賊クライアント、およびキュープロキシーを起動してやります。順序はなんでも構いません。
そうするとワーカーがクラッシュしたり固まったりするでしょうが、キュープロキシーは機能を停止することなく動作し続けます。
このモデルはクライアントやワーカーの数が幾つでも問題なく動作します。

## Robust Reliable Queuing (神経質な海賊パターン)

![神経質な海賊パターン](images/fig49.eps)

;The Simple Pirate Queue pattern works pretty well, especially because it's just a combination of two existing patterns. Still, it does have some weaknesses:

単純な海賊キューパターンは、ものぐさ海賊パターンと組み合わせて上手く機能する障害対策でしたが、これには欠点があります。

;* It's not robust in the face of a queue crash and restart. The client will recover, but the workers won't. While ØMQ will reconnect workers' sockets automatically, as far as the newly started queue is concerned, the workers haven't signaled ready, so don't exist. To fix this, we have to do heartbeating from queue to worker so that the worker can detect when the queue has gone away.
;* The queue does not detect worker failure, so if a worker dies while idle, the queue can't remove it from its worker queue until the queue sends it a request. The client waits and retries for nothing. It's not a critical problem, but it's not nice. To make this work properly, we do heartbeating from worker to queue, so that the queue can detect a lost worker at any stage.

* キューの再起動やクラッシュに対して堅牢ではありません。またクライアントは自動的に復旧しますがワーカーはそうではありません。ワーカーのØMQソケットは自動的に再接続を行ってくれますが、準備完了メッセージを送信していませんのでメッセージが送られてきません。これを修正するにはキュープロキシーからワーカーに対してハートビートを送って、ワーカーの存在を確認する必要があります。
* キュープロキシーはワーカーの障害を検知できないため、待機中のワーカーが落ちてしまった場合にワーカーキューから該当のワーカーを削除することが出来ません。存在しないワーカーに対してメッセージを送信すると、クライアントは待たされてしまうでしょう。これは致命的な問題ではありませんが良くもありません。これを上手く動作させるには、ワーカーからキューに対してハートビートを送るワーカーの障害をキューがワーが検知できるようにするよ良いでしょう。

;We'll fix these in a properly pedantic Paranoid Pirate Pattern.

これらの欠点を神経質な海賊パターンで修正します。

;We previously used a REQ socket for the worker. For the Paranoid Pirate worker, we'll switch to a DEALER socket. This has the advantage of letting us send and receive messages at any time, rather than the lock-step send/receive that REQ imposes. The downside of DEALER is that we have to do our own envelope management (re-read Chapter 3 - Advanced Request-Reply Patterns for background on this concept).

これまでのワーカーはREQソケットを利用してきましたが、この神経質な海賊パターンのワーカーはDEALERソケットを利用します。
これにより、送受信の順序に拘らずにいつでもメッセージを送受信出来るというメリットがあります。
デメリットはメッセージエンベロープを管理しなければならない事です。
これについては第3章の「リクエスト・応答パターンの応用」で既に説明しました。

;We're still using the Lazy Pirate client. Here is the Paranoid Pirate queue proxy:

今回もまたものぐさ海賊パターンのクライアントを使いまわします。
こちらは神経質な海賊キュープロキシーです。

~~~ {caption="ppqueue: Paranoid Pirate queue in C"}
//  Paranoid Pirate queue

#include "czmq.h"
#define HEARTBEAT_LIVENESS  3       //  3-5 is reasonable
#define HEARTBEAT_INTERVAL  1000    //  msecs

//  Paranoid Pirate Protocol constants
#define PPP_READY       "\001"      //  Signals worker is ready
#define PPP_HEARTBEAT   "\002"      //  Signals worker heartbeat

//  .split worker class structure
//  Here we define the worker class; a structure and a set of functions that
//  act as constructor, destructor, and methods on worker objects:

typedef struct {
    zframe_t *identity;         //  Identity of worker
    char *id_string;            //  Printable identity
    int64_t expiry;             //  Expires at this time
} worker_t;

//  Construct new worker
static worker_t *
s_worker_new (zframe_t *identity)
{
    worker_t *self = (worker_t *) zmalloc (sizeof (worker_t));
    self->identity = identity;
    self->id_string = zframe_strhex (identity);
    self->expiry = zclock_time ()
                 + HEARTBEAT_INTERVAL * HEARTBEAT_LIVENESS;
    return self;
}

//  Destroy specified worker object, including identity frame.
static void
s_worker_destroy (worker_t **self_p)
{
    assert (self_p);
    if (*self_p) {
        worker_t *self = *self_p;
        zframe_destroy (&self->identity);
        free (self->id_string);
        free (self);
        *self_p = NULL;
    }
}

//  .split worker ready method
//  The ready method puts a worker to the end of the ready list:

static void
s_worker_ready (worker_t *self, zlist_t *workers)
{
    worker_t *worker = (worker_t *) zlist_first (workers);
    while (worker) {
        if (streq (self->id_string, worker->id_string)) {
            zlist_remove (workers, worker);
            s_worker_destroy (&worker);
            break;
        }
        worker = (worker_t *) zlist_next (workers);
    }
    zlist_append (workers, self);
}

//  .split get next available worker
//  The next method returns the next available worker identity:

static zframe_t *
s_workers_next (zlist_t *workers)
{
    worker_t *worker = zlist_pop (workers);
    assert (worker);
    zframe_t *frame = worker->identity;
    worker->identity = NULL;
    s_worker_destroy (&worker);
    return frame;
}

//  .split purge expired workers
//  The purge method looks for and kills expired workers. We hold workers
//  from oldest to most recent, so we stop at the first alive worker:

static void
s_workers_purge (zlist_t *workers)
{
    worker_t *worker = (worker_t *) zlist_first (workers);
    while (worker) {
        if (zclock_time () < worker->expiry)
            break;              //  Worker is alive, we're done here

        zlist_remove (workers, worker);
        s_worker_destroy (&worker);
        worker = (worker_t *) zlist_first (workers);
    }
}

//  .split main task
//  The main task is a load-balancer with heartbeating on workers so we
//  can detect crashed or blocked worker tasks:

int main (void)
{
    zctx_t *ctx = zctx_new ();
    void *frontend = zsocket_new (ctx, ZMQ_ROUTER);
    void *backend = zsocket_new (ctx, ZMQ_ROUTER);
    zsocket_bind (frontend, "tcp://*:5555");    //  For clients
    zsocket_bind (backend,  "tcp://*:5556");    //  For workers

    //  List of available workers
    zlist_t *workers = zlist_new ();

    //  Send out heartbeats at regular intervals
    uint64_t heartbeat_at = zclock_time () + HEARTBEAT_INTERVAL;

    while (true) {
        zmq_pollitem_t items [] = {
            { backend,  0, ZMQ_POLLIN, 0 },
            { frontend, 0, ZMQ_POLLIN, 0 }
        };
        //  Poll frontend only if we have available workers
        int rc = zmq_poll (items, zlist_size (workers)? 2: 1,
            HEARTBEAT_INTERVAL * ZMQ_POLL_MSEC);
        if (rc == -1)
            break;              //  Interrupted

        //  Handle worker activity on backend
        if (items [0].revents & ZMQ_POLLIN) {
            //  Use worker identity for load-balancing
            zmsg_t *msg = zmsg_recv (backend);
            if (!msg)
                break;          //  Interrupted

            //  Any sign of life from worker means it's ready
            zframe_t *identity = zmsg_unwrap (msg);
            worker_t *worker = s_worker_new (identity);
            s_worker_ready (worker, workers);

            //  Validate control message, or return reply to client
            if (zmsg_size (msg) == 1) {
                zframe_t *frame = zmsg_first (msg);
                if (memcmp (zframe_data (frame), PPP_READY, 1)
                &&  memcmp (zframe_data (frame), PPP_HEARTBEAT, 1)) {
                    printf ("E: invalid message from worker");
                    zmsg_dump (msg);
                }
                zmsg_destroy (&msg);
            }
            else
                zmsg_send (&msg, frontend);
        }
        if (items [1].revents & ZMQ_POLLIN) {
            //  Now get next client request, route to next worker
            zmsg_t *msg = zmsg_recv (frontend);
            if (!msg)
                break;          //  Interrupted
            zmsg_push (msg, s_workers_next (workers));
            zmsg_send (&msg, backend);
        }
        //  .split handle heartbeating
        //  We handle heartbeating after any socket activity. First, we send
        //  heartbeats to any idle workers if it's time. Then, we purge any
        //  dead workers:
        if (zclock_time () >= heartbeat_at) {
            worker_t *worker = (worker_t *) zlist_first (workers);
            while (worker) {
                zframe_send (&worker->identity, backend,
                             ZFRAME_REUSE + ZFRAME_MORE);
                zframe_t *frame = zframe_new (PPP_HEARTBEAT, 1);
                zframe_send (&frame, backend, 0);
                worker = (worker_t *) zlist_next (workers);
            }
            heartbeat_at = zclock_time () + HEARTBEAT_INTERVAL;
        }
        s_workers_purge (workers);
    }
    //  When we're done, clean up properly
    while (zlist_size (workers)) {
        worker_t *worker = (worker_t *) zlist_pop (workers);
        s_worker_destroy (&worker);
    }
    zlist_destroy (&workers);
    zctx_destroy (&ctx);
    return 0;
}
~~~

;The queue extends the load balancing pattern with heartbeating of workers. Heartbeating is one of those "simple" things that can be difficult to get right. I'll explain more about that in a second.

このキュープロキシーは負荷分散パターンを拡張してワーカーに対してハートビートを送信しています。
ハートビートは単純な機能ですが、正しくこれを行うのは難しいので後ほど詳しく説明します。

;Here is the Paranoid Pirate worker:

以下は神経質な海賊パターンのワーカーです。

~~~ {caption"ppworker: Paranoid Pirate worker in C"}
//  Paranoid Pirate worker

#include "czmq.h"
#define HEARTBEAT_LIVENESS  3       //  3-5 is reasonable
#define HEARTBEAT_INTERVAL  1000    //  msecs
#define INTERVAL_INIT       1000    //  Initial reconnect
#define INTERVAL_MAX       32000    //  After exponential backoff

//  Paranoid Pirate Protocol constants
#define PPP_READY       "\001"      //  Signals worker is ready
#define PPP_HEARTBEAT   "\002"      //  Signals worker heartbeat

//  Helper function that returns a new configured socket
//  connected to the Paranoid Pirate queue

static void *
s_worker_socket (zctx_t *ctx) {
    void *worker = zsocket_new (ctx, ZMQ_DEALER);
    zsocket_connect (worker, "tcp://localhost:5556");

    //  Tell queue we're ready for work
    printf ("I: worker ready\n");
    zframe_t *frame = zframe_new (PPP_READY, 1);
    zframe_send (&frame, worker, 0);

    return worker;
}

//  .split main task
//  We have a single task that implements the worker side of the
//  Paranoid Pirate Protocol (PPP). The interesting parts here are
//  the heartbeating, which lets the worker detect if the queue has
//  died, and vice versa:

int main (void)
{
    zctx_t *ctx = zctx_new ();
    void *worker = s_worker_socket (ctx);

    //  If liveness hits zero, queue is considered disconnected
    size_t liveness = HEARTBEAT_LIVENESS;
    size_t interval = INTERVAL_INIT;

    //  Send out heartbeats at regular intervals
    uint64_t heartbeat_at = zclock_time () + HEARTBEAT_INTERVAL;

    srandom ((unsigned) time (NULL));
    int cycles = 0;
    while (true) {
        zmq_pollitem_t items [] = { { worker,  0, ZMQ_POLLIN, 0 } };
        int rc = zmq_poll (items, 1, HEARTBEAT_INTERVAL * ZMQ_POLL_MSEC);
        if (rc == -1)
            break;              //  Interrupted

        if (items [0].revents & ZMQ_POLLIN) {
            //  Get message
            //  - 3-part envelope + content -> request
            //  - 1-part HEARTBEAT -> heartbeat
            zmsg_t *msg = zmsg_recv (worker);
            if (!msg)
                break;          //  Interrupted

            //  .split simulating problems
            //  To test the robustness of the queue implementation we 
            //  simulate various typical problems, such as the worker
            //  crashing or running very slowly. We do this after a few
            //  cycles so that the architecture can get up and running
            //  first:
            if (zmsg_size (msg) == 3) {
                cycles++;
                if (cycles > 3 && randof (5) == 0) {
                    printf ("I: simulating a crash\n");
                    zmsg_destroy (&msg);
                    break;
                }
                else
                if (cycles > 3 && randof (5) == 0) {
                    printf ("I: simulating CPU overload\n");
                    sleep (3);
                    if (zctx_interrupted)
                        break;
                }
                printf ("I: normal reply\n");
                zmsg_send (&msg, worker);
                liveness = HEARTBEAT_LIVENESS;
                sleep (1);              //  Do some heavy work
                if (zctx_interrupted)
                    break;
            }
            else
            //  .split handle heartbeats
            //  When we get a heartbeat message from the queue, it means the
            //  queue was (recently) alive, so we must reset our liveness
            //  indicator:
            if (zmsg_size (msg) == 1) {
                zframe_t *frame = zmsg_first (msg);
                if (memcmp (zframe_data (frame), PPP_HEARTBEAT, 1) == 0)
                    liveness = HEARTBEAT_LIVENESS;
                else {
                    printf ("E: invalid message\n");
                    zmsg_dump (msg);
                }
                zmsg_destroy (&msg);
            }
            else {
                printf ("E: invalid message\n");
                zmsg_dump (msg);
            }
            interval = INTERVAL_INIT;
        }
        else
        //  .split detecting a dead queue
        //  If the queue hasn't sent us heartbeats in a while, destroy the
        //  socket and reconnect. This is the simplest most brutal way of
        //  discarding any messages we might have sent in the meantime:
        if (--liveness == 0) {
            printf ("W: heartbeat failure, can't reach queue\n");
            printf ("W: reconnecting in %zd msec...\n", interval);
            zclock_sleep (interval);

            if (interval < INTERVAL_MAX)
                interval *= 2;
            zsocket_destroy (ctx, worker);
            worker = s_worker_socket (ctx);
            liveness = HEARTBEAT_LIVENESS;
        }
        //  Send heartbeat to queue if it's time
        if (zclock_time () > heartbeat_at) {
            heartbeat_at = zclock_time () + HEARTBEAT_INTERVAL;
            printf ("I: worker heartbeat\n");
            zframe_t *frame = zframe_new (PPP_HEARTBEAT, 1);
            zframe_send (&frame, worker, 0);
        }
    }
    zctx_destroy (&ctx);
    return 0;
}
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
キュープロキシーを再起動した場合でもワーカーは再接続して動作を継続し、ワーカーが1つでも動いていればクライアントは正しい応答を受け取る事が出来るでしょう。

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

### ピンポンハートビート
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
