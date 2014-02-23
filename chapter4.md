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

## 信頼性のあるキューイング(単純な海賊パターン)
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

単純な海賊パターンはものぐさ海賊パターンと組み合わせて上手く機能する障害対策でしたが、これには欠点があります。

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

~~~ {caption="ppworker: Paranoid Pirate worker in C"}
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

Majordomoプロトコルははクライアント側とワーカー側の2種類に分かれますので2つのAPIが必要です。
こちらは単純なオブジェクト指向を利用して設計したクライアント側のAPIです。

~~~
// Majordomo Protocol client example
// Uses the mdcli API to hide all MDP aspects

// Lets us build this source without creating a library
#include "mdcliapi.c"

int main (int argc, char *argv [])
{
    int verbose = (argc > 1 && streq (argv [1], "-v"));
    mdcli_t *session = mdcli_new ("tcp://localhost:5555", verbose);

    int count;
    for (count = 0; count < 100000; count++) {
        zmsg_t *request = zmsg_new ();
        zmsg_pushstr (request, "Hello world");
        zmsg_t *reply = mdcli_send (session, "echo", &request);
        if (reply)
            zmsg_destroy (&reply);
        else
            break; // Interrupt or failure
    }
    printf ("%d requests/replies processed\n", count);
    mdcli_destroy (&session);
    return 0;
}
~~~

;That's it. We open a session to the broker, send a request message, get a reply message back, and eventually close the connection. Here's a sketch for the worker API:

これだけです。
ブローカとのセッションを張り、リクエストを送信して応答を受け取って接続を切っています。
今度はワーカー側のAPIです。

~~~


// Majordomo Protocol worker example
// Uses the mdwrk API to hide all MDP aspects

// Lets us build this source without creating a library
#include "mdwrkapi.c"

int main (int argc, char *argv [])
{
    int verbose = (argc > 1 && streq (argv [1], "-v"));
    mdwrk_t *session = mdwrk_new (
        "tcp://localhost:5555", "echo", verbose);

    zmsg_t *reply = NULL;
    while (true) {
        zmsg_t *request = mdwrk_recv (session, &reply);
        if (request == NULL)
            break; // Worker was interrupted
        reply = request; // Echo is complex… :-)
    }
    mdwrk_destroy (&session);
    return 0;
}
~~~

;It's more or less symmetrical, but the worker dialog is a little different. The first time a worker does a recv(), it passes a null reply. Thereafter, it passes the current reply, and gets a new request.

これは対称的なコードに見えるかもしれませんが、ワーカー側のやりとりにちょっとした違いがあります。
初回のrecv()呼び出しではnullを受け取り、続いてリクエストを受信します。

The client and worker APIs were fairly simple to construct because they're heavily based on the Paranoid Pirate code we already developed. Here is the client API:
クライアントとワーカーは既に実装済みの神経質な海賊パターンのコードを流用する事で、今回のAPIはとても簡単に設計することができました。

~~~ {caption="mdcliapi: Majordomo client API in C"}
//  mdcliapi class - Majordomo Protocol Client API
//  Implements the MDP/Worker spec at http://rfc.zeromq.org/spec:7.

#include "mdcliapi.h"

//  Structure of our class
//  We access these properties only via class methods

struct _mdcli_t {
    zctx_t *ctx;                //  Our context
    char *broker;
    void *client;               //  Socket to broker
    int verbose;                //  Print activity to stdout
    int timeout;                //  Request timeout
    int retries;                //  Request retries
};

//  Connect or reconnect to broker

void s_mdcli_connect_to_broker (mdcli_t *self)
{
    if (self->client)
        zsocket_destroy (self->ctx, self->client);
    self->client = zsocket_new (self->ctx, ZMQ_REQ);
    zmq_connect (self->client, self->broker);
    if (self->verbose)
        zclock_log ("I: connecting to broker at %s...", self->broker);
}

//  .split constructor and destructor
//  Here we have the constructor and destructor for our class:

//  Constructor

mdcli_t *
mdcli_new (char *broker, int verbose)
{
    assert (broker);

    mdcli_t *self = (mdcli_t *) zmalloc (sizeof (mdcli_t));
    self->ctx = zctx_new ();
    self->broker = strdup (broker);
    self->verbose = verbose;
    self->timeout = 2500;           //  msecs
    self->retries = 3;              //  Before we abandon

    s_mdcli_connect_to_broker (self);
    return self;
}

//  Destructor

void
mdcli_destroy (mdcli_t **self_p)
{
    assert (self_p);
    if (*self_p) {
        mdcli_t *self = *self_p;
        zctx_destroy (&self->ctx);
        free (self->broker);
        free (self);
        *self_p = NULL;
    }
}

//  .split configure retry behavior
//  These are the class methods. We can set the request timeout and number
//  of retry attempts before sending requests:

//  Set request timeout

void
mdcli_set_timeout (mdcli_t *self, int timeout)
{
    assert (self);
    self->timeout = timeout;
}

//  Set request retries

void
mdcli_set_retries (mdcli_t *self, int retries)
{
    assert (self);
    self->retries = retries;
}

//  .split send request and wait for reply
//  Here is the {{send}} method. It sends a request to the broker and gets
//  a reply even if it has to retry several times. It takes ownership of 
//  the request message, and destroys it when sent. It returns the reply
//  message, or NULL if there was no reply after multiple attempts:

zmsg_t *
mdcli_send (mdcli_t *self, char *service, zmsg_t **request_p)
{
    assert (self);
    assert (request_p);
    zmsg_t *request = *request_p;

    //  Prefix request with protocol frames
    //  Frame 1: "MDPCxy" (six bytes, MDP/Client x.y)
    //  Frame 2: Service name (printable string)
    zmsg_pushstr (request, service);
    zmsg_pushstr (request, MDPC_CLIENT);
    if (self->verbose) {
        zclock_log ("I: send request to '%s' service:", service);
        zmsg_dump (request);
    }
    int retries_left = self->retries;
    while (retries_left && !zctx_interrupted) {
        zmsg_t *msg = zmsg_dup (request);
        zmsg_send (&msg, self->client);

        zmq_pollitem_t items [] = {
            { self->client, 0, ZMQ_POLLIN, 0 }
        };
        //  .split body of send 
        //  On any blocking call, {{libzmq}} will return -1 if there was
        //  an error; we could in theory check for different error codes,
        //  but in practice it's OK to assume it was {{EINTR}} (Ctrl-C):
        
        int rc = zmq_poll (items, 1, self->timeout * ZMQ_POLL_MSEC);
        if (rc == -1)
            break;          //  Interrupted

        //  If we got a reply, process it
        if (items [0].revents & ZMQ_POLLIN) {
            zmsg_t *msg = zmsg_recv (self->client);
            if (self->verbose) {
                zclock_log ("I: received reply:");
                zmsg_dump (msg);
            }
            //  We would handle malformed replies better in real code
            assert (zmsg_size (msg) >= 3);

            zframe_t *header = zmsg_pop (msg);
            assert (zframe_streq (header, MDPC_CLIENT));
            zframe_destroy (&header);

            zframe_t *reply_service = zmsg_pop (msg);
            assert (zframe_streq (reply_service, service));
            zframe_destroy (&reply_service);

            zmsg_destroy (&request);
            return msg;     //  Success
        }
        else
        if (--retries_left) {
            if (self->verbose)
                zclock_log ("W: no reply, reconnecting...");
            s_mdcli_connect_to_broker (self);
        }
        else {
            if (self->verbose)
                zclock_log ("W: permanent error, abandoning");
            break;          //  Give up
        }
    }
    if (zctx_interrupted)
        printf ("W: interrupt received, killing client...\n");
    zmsg_destroy (&request);
    return NULL;
}
~~~

;Let's see how the client API looks in action, with an example test program that does 100K request-reply cycles:

それではクライアントAPIを動かしてみましょう。
こちらは10万回のリクエスト・応答のサイクルを実行するテストコードです。

~~~{caption="mdclient: Majordomo client application in C"}
//  Majordomo Protocol client example
//  Uses the mdcli API to hide all MDP aspects

//  Lets us build this source without creating a library
#include "mdcliapi.c"

int main (int argc, char *argv [])
{
    int verbose = (argc > 1 && streq (argv [1], "-v"));
    mdcli_t *session = mdcli_new ("tcp://localhost:5555", verbose);

    int count;
    for (count = 0; count < 100000; count++) {
        zmsg_t *request = zmsg_new ();
        zmsg_pushstr (request, "Hello world");
        zmsg_t *reply = mdcli_send (session, "echo", &request);
        if (reply)
            zmsg_destroy (&reply);
        else
            break;              //  Interrupt or failure
    }
    printf ("%d requests/replies processed\n", count);
    mdcli_destroy (&session);
    return 0;
}
~~~

;And here is the worker API:

そしてこちらはワーカーのAPIです。

~~~ {caption="mdwrkapi: Majordomo worker API in C"}
//  mdwrkapi class - Majordomo Protocol Worker API
//  Implements the MDP/Worker spec at http://rfc.zeromq.org/spec:7.

#include "mdwrkapi.h"

//  Reliability parameters
#define HEARTBEAT_LIVENESS  3       //  3-5 is reasonable

//  .split worker class structure
//  This is the structure of a worker API instance. We use a pseudo-OO
//  approach in a lot of the C examples, as well as the CZMQ binding:

//  Structure of our class
//  We access these properties only via class methods

struct _mdwrk_t {
    zctx_t *ctx;                //  Our context
    char *broker;
    char *service;
    void *worker;               //  Socket to broker
    int verbose;                //  Print activity to stdout

    //  Heartbeat management
    uint64_t heartbeat_at;      //  When to send HEARTBEAT
    size_t liveness;            //  How many attempts left
    int heartbeat;              //  Heartbeat delay, msecs
    int reconnect;              //  Reconnect delay, msecs

    int expect_reply;           //  Zero only at start
    zframe_t *reply_to;         //  Return identity, if any
};

//  .split utility functions
//  We have two utility functions; to send a message to the broker and
//  to (re)connect to the broker:

//  Send message to broker
//  If no msg is provided, creates one internally

static void
s_mdwrk_send_to_broker (mdwrk_t *self, char *command, char *option,
                        zmsg_t *msg)
{
    msg = msg? zmsg_dup (msg): zmsg_new ();

    //  Stack protocol envelope to start of message
    if (option)
        zmsg_pushstr (msg, option);
    zmsg_pushstr (msg, command);
    zmsg_pushstr (msg, MDPW_WORKER);
    zmsg_pushstr (msg, "");

    if (self->verbose) {
        zclock_log ("I: sending %s to broker",
            mdps_commands [(int) *command]);
        zmsg_dump (msg);
    }
    zmsg_send (&msg, self->worker);
}

//  Connect or reconnect to broker

void s_mdwrk_connect_to_broker (mdwrk_t *self)
{
    if (self->worker)
        zsocket_destroy (self->ctx, self->worker);
    self->worker = zsocket_new (self->ctx, ZMQ_DEALER);
    zmq_connect (self->worker, self->broker);
    if (self->verbose)
        zclock_log ("I: connecting to broker at %s...", self->broker);

    //  Register service with broker
    s_mdwrk_send_to_broker (self, MDPW_READY, self->service, NULL);

    //  If liveness hits zero, queue is considered disconnected
    self->liveness = HEARTBEAT_LIVENESS;
    self->heartbeat_at = zclock_time () + self->heartbeat;
}

//  .split constructor and destructor
//  Here we have the constructor and destructor for our mdwrk class:

//  Constructor

mdwrk_t *
mdwrk_new (char *broker,char *service, int verbose)
{
    assert (broker);
    assert (service);

    mdwrk_t *self = (mdwrk_t *) zmalloc (sizeof (mdwrk_t));
    self->ctx = zctx_new ();
    self->broker = strdup (broker);
    self->service = strdup (service);
    self->verbose = verbose;
    self->heartbeat = 2500;     //  msecs
    self->reconnect = 2500;     //  msecs

    s_mdwrk_connect_to_broker (self);
    return self;
}

//  Destructor

void
mdwrk_destroy (mdwrk_t **self_p)
{
    assert (self_p);
    if (*self_p) {
        mdwrk_t *self = *self_p;
        zctx_destroy (&self->ctx);
        free (self->broker);
        free (self->service);
        free (self);
        *self_p = NULL;
    }
}

//  .split configure worker
//  We provide two methods to configure the worker API. You can set the
//  heartbeat interval and retries to match the expected network performance.

//  Set heartbeat delay

void
mdwrk_set_heartbeat (mdwrk_t *self, int heartbeat)
{
    self->heartbeat = heartbeat;
}

//  Set reconnect delay

void
mdwrk_set_reconnect (mdwrk_t *self, int reconnect)
{
    self->reconnect = reconnect;
}

//  .split recv method
//  This is the {{recv}} method; it's a little misnamed because it first sends
//  any reply and then waits for a new request. If you have a better name
//  for this, let me know.

//  Send reply, if any, to broker and wait for next request.

zmsg_t *
mdwrk_recv (mdwrk_t *self, zmsg_t **reply_p)
{
    //  Format and send the reply if we were provided one
    assert (reply_p);
    zmsg_t *reply = *reply_p;
    assert (reply || !self->expect_reply);
    if (reply) {
        assert (self->reply_to);
        zmsg_wrap (reply, self->reply_to);
        s_mdwrk_send_to_broker (self, MDPW_REPLY, NULL, reply);
        zmsg_destroy (reply_p);
    }
    self->expect_reply = 1;

    while (true) {
        zmq_pollitem_t items [] = {
            { self->worker,  0, ZMQ_POLLIN, 0 } };
        int rc = zmq_poll (items, 1, self->heartbeat * ZMQ_POLL_MSEC);
        if (rc == -1)
            break;              //  Interrupted

        if (items [0].revents & ZMQ_POLLIN) {
            zmsg_t *msg = zmsg_recv (self->worker);
            if (!msg)
                break;          //  Interrupted
            if (self->verbose) {
                zclock_log ("I: received message from broker:");
                zmsg_dump (msg);
            }
            self->liveness = HEARTBEAT_LIVENESS;

            //  Don't try to handle errors, just assert noisily
            assert (zmsg_size (msg) >= 3);

            zframe_t *empty = zmsg_pop (msg);
            assert (zframe_streq (empty, ""));
            zframe_destroy (&empty);

            zframe_t *header = zmsg_pop (msg);
            assert (zframe_streq (header, MDPW_WORKER));
            zframe_destroy (&header);

            zframe_t *command = zmsg_pop (msg);
            if (zframe_streq (command, MDPW_REQUEST)) {
                //  We should pop and save as many addresses as there are
                //  up to a null part, but for now, just save one...
                self->reply_to = zmsg_unwrap (msg);
                zframe_destroy (&command);
                //  .split process message
                //  Here is where we actually have a message to process; we
                //  return it to the caller application:
                
                return msg;     //  We have a request to process
            }
            else
            if (zframe_streq (command, MDPW_HEARTBEAT))
                ;               //  Do nothing for heartbeats
            else
            if (zframe_streq (command, MDPW_DISCONNECT))
                s_mdwrk_connect_to_broker (self);
            else {
                zclock_log ("E: invalid input message");
                zmsg_dump (msg);
            }
            zframe_destroy (&command);
            zmsg_destroy (&msg);
        }
        else
        if (--self->liveness == 0) {
            if (self->verbose)
                zclock_log ("W: disconnected from broker - retrying...");
            zclock_sleep (self->reconnect);
            s_mdwrk_connect_to_broker (self);
        }
        //  Send HEARTBEAT if it's time
        if (zclock_time () > self->heartbeat_at) {
            s_mdwrk_send_to_broker (self, MDPW_HEARTBEAT, NULL, NULL);
            self->heartbeat_at = zclock_time () + self->heartbeat;
        }
    }
    if (zctx_interrupted)
        printf ("W: interrupt received, killing worker...\n");
    return NULL;
}
~~~

;Let's see how the worker API looks in action, with an example test program that implements an echo service:


ワーカーのAPIを用いてechoサービスを実装するテストコードを見て行きましょう。

~~~ {caption="mdworker: Majordomo worker application in C"}
//  Majordomo Protocol worker example
//  Uses the mdwrk API to hide all MDP aspects

//  Lets us build this source without creating a library
#include "mdwrkapi.c"

int main (int argc, char *argv [])
{
    int verbose = (argc > 1 && streq (argv [1], "-v"));
    mdwrk_t *session = mdwrk_new (
        "tcp://localhost:5555", "echo", verbose);

    zmsg_t *reply = NULL;
    while (true) {
        zmsg_t *request = mdwrk_recv (session, &reply);
        if (request == NULL)
            break;              //  Worker was interrupted
        reply = request;        //  Echo is complex... :-)
    }
    mdwrk_destroy (&session);
    return 0;
}
~~~

;Here are some things to note about the worker API code:

ワーカーAPIについて注意すべき点を挙げます。

;* The APIs are single-threaded. This means, for example, that the worker won't send heartbeats in the background. Happily, this is exactly what we want: if the worker application gets stuck, heartbeats will stop and the broker will stop sending requests to the worker.
;* The worker API doesn't do an exponential back-off; it's not worth the extra complexity.
;* The APIs don't do any error reporting. If something isn't as expected, they raise an assertion (or exception depending on the language). This is ideal for a reference implementation, so any protocol errors show immediately. For real applications, the API should be robust against invalid messages.

* このAPIはシングルスレッドで動作します。例えばバックグラウンドスレッドでハートビートを送信しないでください。
* このAPIは指数的な間隔で再試行を行いません。
* このAPIはエラー報告を行いません。必要に応じてアサーションや例外を投げたりすると良いでしょう。これは仮の参照実装ですので実際のアプリケーションでは不正なメッセージに対して堅牢でなくてはなりません。

;You might wonder why the worker API is manually closing its socket and opening a new one, when ØMQ will automatically reconnect a socket if the peer disappears and comes back. Look back at the Simple Pirate and Paranoid Pirate workers to understand. Although ØMQ will automatically reconnect workers if the broker dies and comes back up, this isn't sufficient to re-register the workers with the broker. I know of at least two solutions. The simplest, which we use here, is for the worker to monitor the connection using heartbeats, and if it decides the broker is dead, to close its socket and start afresh with a new socket. The alternative is for the broker to challenge unknown workers when it gets a heartbeat from the worker and ask them to re-register. That would require protocol support.

;[TODO]

;Now let's design the Majordomo broker. Its core structure is a set of queues, one per service. We will create these queues as workers appear (we could delete them as workers disappear, but forget that for now because it gets complex). Additionally, we keep a queue of workers per service.

それではMajordomoブローカーを設計してみましょう。
基本的な構造としてサービス毎にひとつのキューを持っていて、このキューはワーカーが接続した時に生成されます。

;And here is the broker:

こちらがブローカーのコードです。

~~~{caption="mdbroker: Majordomo broker in C"}
//  Majordomo Protocol broker
//  A minimal C implementation of the Majordomo Protocol as defined in
//  http://rfc.zeromq.org/spec:7 and http://rfc.zeromq.org/spec:8.

#include "czmq.h"
#include "mdp.h"

//  We'd normally pull these from config data

#define HEARTBEAT_LIVENESS  3       //  3-5 is reasonable
#define HEARTBEAT_INTERVAL  2500    //  msecs
#define HEARTBEAT_EXPIRY    HEARTBEAT_INTERVAL * HEARTBEAT_LIVENESS

//  .split broker class structure
//  The broker class defines a single broker instance:

typedef struct {
    zctx_t *ctx;                //  Our context
    void *socket;               //  Socket for clients & workers
    int verbose;                //  Print activity to stdout
    char *endpoint;             //  Broker binds to this endpoint
    zhash_t *services;          //  Hash of known services
    zhash_t *workers;           //  Hash of known workers
    zlist_t *waiting;           //  List of waiting workers
    uint64_t heartbeat_at;      //  When to send HEARTBEAT
} broker_t;

static broker_t *
    s_broker_new (int verbose);
static void
    s_broker_destroy (broker_t **self_p);
static void
    s_broker_bind (broker_t *self, char *endpoint);
static void
    s_broker_worker_msg (broker_t *self, zframe_t *sender, zmsg_t *msg);
static void
    s_broker_client_msg (broker_t *self, zframe_t *sender, zmsg_t *msg);
static void
    s_broker_purge (broker_t *self);

//  .split service class structure
//  The service class defines a single service instance:

typedef struct {
    broker_t *broker;           //  Broker instance
    char *name;                 //  Service name
    zlist_t *requests;          //  List of client requests
    zlist_t *waiting;           //  List of waiting workers
    size_t workers;             //  How many workers we have
} service_t;

static service_t *
    s_service_require (broker_t *self, zframe_t *service_frame);
static void
    s_service_destroy (void *argument);
static void
    s_service_dispatch (service_t *service, zmsg_t *msg);

//  .split worker class structure
//  The worker class defines a single worker, idle or active:

typedef struct {
    broker_t *broker;           //  Broker instance
    char *id_string;            //  Identity of worker as string
    zframe_t *identity;         //  Identity frame for routing
    service_t *service;         //  Owning service, if known
    int64_t expiry;             //  When worker expires, if no heartbeat
} worker_t;

static worker_t *
    s_worker_require (broker_t *self, zframe_t *identity);
static void
    s_worker_delete (worker_t *self, int disconnect);
static void
    s_worker_destroy (void *argument);
static void
    s_worker_send (worker_t *self, char *command, char *option,
                   zmsg_t *msg);
static void
    s_worker_waiting (worker_t *self);

//  .split broker constructor and destructor
//  Here are the constructor and destructor for the broker:

static broker_t *
s_broker_new (int verbose)
{
    broker_t *self = (broker_t *) zmalloc (sizeof (broker_t));

    //  Initialize broker state
    self->ctx = zctx_new ();
    self->socket = zsocket_new (self->ctx, ZMQ_ROUTER);
    self->verbose = verbose;
    self->services = zhash_new ();
    self->workers = zhash_new ();
    self->waiting = zlist_new ();
    self->heartbeat_at = zclock_time () + HEARTBEAT_INTERVAL;
    return self;
}

static void
s_broker_destroy (broker_t **self_p)
{
    assert (self_p);
    if (*self_p) {
        broker_t *self = *self_p;
        zctx_destroy (&self->ctx);
        zhash_destroy (&self->services);
        zhash_destroy (&self->workers);
        zlist_destroy (&self->waiting);
        free (self);
        *self_p = NULL;
    }
}

//  .split broker bind method
//  This method binds the broker instance to an endpoint. We can call
//  this multiple times. Note that MDP uses a single socket for both clients 
//  and workers:

void
s_broker_bind (broker_t *self, char *endpoint)
{
    zsocket_bind (self->socket, endpoint);
    zclock_log ("I: MDP broker/0.2.0 is active at %s", endpoint);
}

//  .split broker worker_msg method
//  This method processes one READY, REPLY, HEARTBEAT, or
//  DISCONNECT message sent to the broker by a worker:

static void
s_broker_worker_msg (broker_t *self, zframe_t *sender, zmsg_t *msg)
{
    assert (zmsg_size (msg) >= 1);     //  At least, command

    zframe_t *command = zmsg_pop (msg);
    char *id_string = zframe_strhex (sender);
    int worker_ready = (zhash_lookup (self->workers, id_string) != NULL);
    free (id_string);
    worker_t *worker = s_worker_require (self, sender);

    if (zframe_streq (command, MDPW_READY)) {
        if (worker_ready)               //  Not first command in session
            s_worker_delete (worker, 1);
        else
        if (zframe_size (sender) >= 4  //  Reserved service name
        &&  memcmp (zframe_data (sender), "mmi.", 4) == 0)
            s_worker_delete (worker, 1);
        else {
            //  Attach worker to service and mark as idle
            zframe_t *service_frame = zmsg_pop (msg);
            worker->service = s_service_require (self, service_frame);
            worker->service->workers++;
            s_worker_waiting (worker);
            zframe_destroy (&service_frame);
        }
    }
    else
    if (zframe_streq (command, MDPW_REPLY)) {
        if (worker_ready) {
            //  Remove and save client return envelope and insert the
            //  protocol header and service name, then rewrap envelope.
            zframe_t *client = zmsg_unwrap (msg);
            zmsg_pushstr (msg, worker->service->name);
            zmsg_pushstr (msg, MDPC_CLIENT);
            zmsg_wrap (msg, client);
            zmsg_send (&msg, self->socket);
            s_worker_waiting (worker);
        }
        else
            s_worker_delete (worker, 1);
    }
    else
    if (zframe_streq (command, MDPW_HEARTBEAT)) {
        if (worker_ready)
            worker->expiry = zclock_time () + HEARTBEAT_EXPIRY;
        else
            s_worker_delete (worker, 1);
    }
    else
    if (zframe_streq (command, MDPW_DISCONNECT))
        s_worker_delete (worker, 0);
    else {
        zclock_log ("E: invalid input message");
        zmsg_dump (msg);
    }
    free (command);
    zmsg_destroy (&msg);
}

//  .split broker client_msg method
//  Process a request coming from a client. We implement MMI requests
//  directly here (at present, we implement only the mmi.service request):

static void
s_broker_client_msg (broker_t *self, zframe_t *sender, zmsg_t *msg)
{
    assert (zmsg_size (msg) >= 2);     //  Service name + body

    zframe_t *service_frame = zmsg_pop (msg);
    service_t *service = s_service_require (self, service_frame);

    //  Set reply return identity to client sender
    zmsg_wrap (msg, zframe_dup (sender));

    //  If we got a MMI service request, process that internally
    if (zframe_size (service_frame) >= 4
    &&  memcmp (zframe_data (service_frame), "mmi.", 4) == 0) {
        char *return_code;
        if (zframe_streq (service_frame, "mmi.service")) {
            char *name = zframe_strdup (zmsg_last (msg));
            service_t *service =
                (service_t *) zhash_lookup (self->services, name);
            return_code = service && service->workers? "200": "404";
            free (name);
        }
        else
            return_code = "501";

        zframe_reset (zmsg_last (msg), return_code, strlen (return_code));

        //  Remove & save client return envelope and insert the
        //  protocol header and service name, then rewrap envelope.
        zframe_t *client = zmsg_unwrap (msg);
        zmsg_push (msg, zframe_dup (service_frame));
        zmsg_pushstr (msg, MDPC_CLIENT);
        zmsg_wrap (msg, client);
        zmsg_send (&msg, self->socket);
    }
    else
        //  Else dispatch the message to the requested service
        s_service_dispatch (service, msg);
    zframe_destroy (&service_frame);
}

//  .split broker purge method
//  This method deletes any idle workers that haven't pinged us in a
//  while. We hold workers from oldest to most recent so we can stop
//  scanning whenever we find a live worker. This means we'll mainly stop
//  at the first worker, which is essential when we have large numbers of
//  workers (we call this method in our critical path):

static void
s_broker_purge (broker_t *self)
{
    worker_t *worker = (worker_t *) zlist_first (self->waiting);
    while (worker) {
        if (zclock_time () < worker->expiry)
            break;                  //  Worker is alive, we're done here
        if (self->verbose)
            zclock_log ("I: deleting expired worker: %s",
                        worker->id_string);

        s_worker_delete (worker, 0);
        worker = (worker_t *) zlist_first (self->waiting);
    }
}

//  .split service methods
//  Here is the implementation of the methods that work on a service:

//  Lazy constructor that locates a service by name or creates a new
//  service if there is no service already with that name.

static service_t *
s_service_require (broker_t *self, zframe_t *service_frame)
{
    assert (service_frame);
    char *name = zframe_strdup (service_frame);

    service_t *service =
        (service_t *) zhash_lookup (self->services, name);
    if (service == NULL) {
        service = (service_t *) zmalloc (sizeof (service_t));
        service->broker = self;
        service->name = name;
        service->requests = zlist_new ();
        service->waiting = zlist_new ();
        zhash_insert (self->services, name, service);
        zhash_freefn (self->services, name, s_service_destroy);
        if (self->verbose)
            zclock_log ("I: added service: %s", name);
    }
    else
        free (name);

    return service;
}

//  Service destructor is called automatically whenever the service is
//  removed from broker->services.

static void
s_service_destroy (void *argument)
{
    service_t *service = (service_t *) argument;
    while (zlist_size (service->requests)) {
        zmsg_t *msg = zlist_pop (service->requests);
        zmsg_destroy (&msg);
    }
    zlist_destroy (&service->requests);
    zlist_destroy (&service->waiting);
    free (service->name);
    free (service);
}

//  .split service dispatch method
//  This method sends requests to waiting workers:

static void
s_service_dispatch (service_t *self, zmsg_t *msg)
{
    assert (self);
    if (msg)                    //  Queue message if any
        zlist_append (self->requests, msg);

    s_broker_purge (self->broker);
    while (zlist_size (self->waiting) && zlist_size (self->requests)) {
        worker_t *worker = zlist_pop (self->waiting);
        zlist_remove (self->broker->waiting, worker);
        zmsg_t *msg = zlist_pop (self->requests);
        s_worker_send (worker, MDPW_REQUEST, NULL, msg);
        zmsg_destroy (&msg);
    }
}

//  .split worker methods
//  Here is the implementation of the methods that work on a worker:

//  Lazy constructor that locates a worker by identity, or creates a new
//  worker if there is no worker already with that identity.

static worker_t *
s_worker_require (broker_t *self, zframe_t *identity)
{
    assert (identity);

    //  self->workers is keyed off worker identity
    char *id_string = zframe_strhex (identity);
    worker_t *worker =
        (worker_t *) zhash_lookup (self->workers, id_string);

    if (worker == NULL) {
        worker = (worker_t *) zmalloc (sizeof (worker_t));
        worker->broker = self;
        worker->id_string = id_string;
        worker->identity = zframe_dup (identity);
        zhash_insert (self->workers, id_string, worker);
        zhash_freefn (self->workers, id_string, s_worker_destroy);
        if (self->verbose)
            zclock_log ("I: registering new worker: %s", id_string);
    }
    else
        free (id_string);
    return worker;
}

//  This method deletes the current worker.

static void
s_worker_delete (worker_t *self, int disconnect)
{
    assert (self);
    if (disconnect)
        s_worker_send (self, MDPW_DISCONNECT, NULL, NULL);

    if (self->service) {
        zlist_remove (self->service->waiting, self);
        self->service->workers--;
    }
    zlist_remove (self->broker->waiting, self);
    //  This implicitly calls s_worker_destroy
    zhash_delete (self->broker->workers, self->id_string);
}

//  Worker destructor is called automatically whenever the worker is
//  removed from broker->workers.

static void
s_worker_destroy (void *argument)
{
    worker_t *self = (worker_t *) argument;
    zframe_destroy (&self->identity);
    free (self->id_string);
    free (self);
}

//  .split worker send method
//  This method formats and sends a command to a worker. The caller may
//  also provide a command option, and a message payload:

static void
s_worker_send (worker_t *self, char *command, char *option, zmsg_t *msg)
{
    msg = msg? zmsg_dup (msg): zmsg_new ();

    //  Stack protocol envelope to start of message
    if (option)
        zmsg_pushstr (msg, option);
    zmsg_pushstr (msg, command);
    zmsg_pushstr (msg, MDPW_WORKER);

    //  Stack routing envelope to start of message
    zmsg_wrap (msg, zframe_dup (self->identity));

    if (self->broker->verbose) {
        zclock_log ("I: sending %s to worker",
            mdps_commands [(int) *command]);
        zmsg_dump (msg);
    }
    zmsg_send (&msg, self->broker->socket);
}

//  This worker is now waiting for work

static void
s_worker_waiting (worker_t *self)
{
    //  Queue to broker and service waiting lists
    assert (self->broker);
    zlist_append (self->broker->waiting, self);
    zlist_append (self->service->waiting, self);
    self->expiry = zclock_time () + HEARTBEAT_EXPIRY;
    s_service_dispatch (self->service, NULL);
}

//  .split main task
//  Finally, here is the main task. We create a new broker instance and
//  then process messages on the broker socket:

int main (int argc, char *argv [])
{
    int verbose = (argc > 1 && streq (argv [1], "-v"));

    broker_t *self = s_broker_new (verbose);
    s_broker_bind (self, "tcp://*:5555");

    //  Get and process messages forever or until interrupted
    while (true) {
        zmq_pollitem_t items [] = {
            { self->socket,  0, ZMQ_POLLIN, 0 } };
        int rc = zmq_poll (items, 1, HEARTBEAT_INTERVAL * ZMQ_POLL_MSEC);
        if (rc == -1)
            break;              //  Interrupted

        //  Process next input message, if any
        if (items [0].revents & ZMQ_POLLIN) {
            zmsg_t *msg = zmsg_recv (self->socket);
            if (!msg)
                break;          //  Interrupted
            if (self->verbose) {
                zclock_log ("I: received message:");
                zmsg_dump (msg);
            }
            zframe_t *sender = zmsg_pop (msg);
            zframe_t *empty  = zmsg_pop (msg);
            zframe_t *header = zmsg_pop (msg);

            if (zframe_streq (header, MDPC_CLIENT))
                s_broker_client_msg (self, sender, msg);
            else
            if (zframe_streq (header, MDPW_WORKER))
                s_broker_worker_msg (self, sender, msg);
            else {
                zclock_log ("E: invalid message:");
                zmsg_dump (msg);
                zmsg_destroy (&msg);
            }
            zframe_destroy (&sender);
            zframe_destroy (&empty);
            zframe_destroy (&header);
        }
        //  Disconnect and delete any expired workers
        //  Send heartbeats to idle workers if needed
        if (zclock_time () > self->heartbeat_at) {
            s_broker_purge (self);
            worker_t *worker = (worker_t *) zlist_first (self->waiting);
            while (worker) {
                s_worker_send (worker, MDPW_HEARTBEAT, NULL, NULL);
                worker = (worker_t *) zlist_next (self->waiting);
            }
            self->heartbeat_at = zclock_time () + HEARTBEAT_INTERVAL;
        }
    }
    if (zctx_interrupted)
        printf ("W: interrupt received, shutting down...\n");

    s_broker_destroy (&self);
    return 0;
}
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

~~~ {caption="tripping: Round-trip demonstrator in C"}
//  Round-trip demonstrator
//  While this example runs in a single process, that is just to make
//  it easier to start and stop the example. The client task signals to
//  main when it's ready.

#include "czmq.h"

static void
client_task (void *args, zctx_t *ctx, void *pipe)
{
    void *client = zsocket_new (ctx, ZMQ_DEALER);
    zsocket_connect (client, "tcp://localhost:5555");
    printf ("Setting up test...\n");
    zclock_sleep (100);

    int requests;
    int64_t start;

    printf ("Synchronous round-trip test...\n");
    start = zclock_time ();
    for (requests = 0; requests < 10000; requests++) {
        zstr_send (client, "hello");
        char *reply = zstr_recv (client);
        free (reply);
    }
    printf (" %d calls/second\n",
        (1000 * 10000) / (int) (zclock_time () - start));

    printf ("Asynchronous round-trip test...\n");
    start = zclock_time ();
    for (requests = 0; requests < 100000; requests++)
        zstr_send (client, "hello");
    for (requests = 0; requests < 100000; requests++) {
        char *reply = zstr_recv (client);
        free (reply);
    }
    printf (" %d calls/second\n",
        (1000 * 100000) / (int) (zclock_time () - start));
    zstr_send (pipe, "done");
}

//  .split worker task
//  Here is the worker task. All it does is receive a message, and
//  bounce it back the way it came:

static void *
worker_task (void *args)
{
    zctx_t *ctx = zctx_new ();
    void *worker = zsocket_new (ctx, ZMQ_DEALER);
    zsocket_connect (worker, "tcp://localhost:5556");
    
    while (true) {
        zmsg_t *msg = zmsg_recv (worker);
        zmsg_send (&msg, worker);
    }
    zctx_destroy (&ctx);
    return NULL;
}

//  .split broker task
//  Here is the broker task. It uses the {{zmq_proxy}} function to switch
//  messages between frontend and backend:

static void *
broker_task (void *args)
{
    //  Prepare our context and sockets
    zctx_t *ctx = zctx_new ();
    void *frontend = zsocket_new (ctx, ZMQ_DEALER);
    zsocket_bind (frontend, "tcp://*:5555");
    void *backend = zsocket_new (ctx, ZMQ_DEALER);
    zsocket_bind (backend, "tcp://*:5556");
    zmq_proxy (frontend, backend, NULL);
    zctx_destroy (&ctx);
    return NULL;
}

//  .split main task
//  Finally, here's the main task, which starts the client, worker, and
//  broker, and then runs until the client signals it to stop:

int main (void)
{
    //  Create threads
    zctx_t *ctx = zctx_new ();
    void *client = zthread_fork (ctx, client_task, NULL);
    zthread_new (worker_task, NULL);
    zthread_new (broker_task, NULL);

    //  Wait for signal on client pipe
    char *signal = zstr_recv (client);
    free (signal);

    zctx_destroy (&ctx);
    return 0;
}
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

同期式クライアントを非同期に書き換えるのはほんの数分の手間です。

~~~{caption="mdcliapi2: Majordomo asynchronous client API in C"}
//  mdcliapi2 class - Majordomo Protocol Client API
//  Implements the MDP/Worker spec at http://rfc.zeromq.org/spec:7.

#include "mdcliapi2.h"

//  Structure of our class
//  We access these properties only via class methods

struct _mdcli_t {
    zctx_t *ctx;                //  Our context
    char *broker;
    void *client;               //  Socket to broker
    int verbose;                //  Print activity to stdout
    int timeout;                //  Request timeout
};

//  Connect or reconnect to broker. In this asynchronous class we use a
//  DEALER socket instead of a REQ socket; this lets us send any number
//  of requests without waiting for a reply.

void s_mdcli_connect_to_broker (mdcli_t *self)
{
    if (self->client)
        zsocket_destroy (self->ctx, self->client);
    self->client = zsocket_new (self->ctx, ZMQ_DEALER);
    zmq_connect (self->client, self->broker);
    if (self->verbose)
        zclock_log ("I: connecting to broker at %s...", self->broker);
}

//  The constructor and destructor are the same as in mdcliapi, except
//  we don't do retries, so there's no retries property.
//  .skip
//  ---------------------------------------------------------------------
//  Constructor

mdcli_t *
mdcli_new (char *broker, int verbose)
{
    assert (broker);

    mdcli_t *self = (mdcli_t *) zmalloc (sizeof (mdcli_t));
    self->ctx = zctx_new ();
    self->broker = strdup (broker);
    self->verbose = verbose;
    self->timeout = 2500;           //  msecs

    s_mdcli_connect_to_broker (self);
    return self;
}

//  Destructor

void
mdcli_destroy (mdcli_t **self_p)
{
    assert (self_p);
    if (*self_p) {
        mdcli_t *self = *self_p;
        zctx_destroy (&self->ctx);
        free (self->broker);
        free (self);
        *self_p = NULL;
    }
}

//  Set request timeout

void
mdcli_set_timeout (mdcli_t *self, int timeout)
{
    assert (self);
    self->timeout = timeout;
}

//  .until
//  .skip
//  The send method now just sends one message, without waiting for a
//  reply. Since we're using a DEALER socket we have to send an empty
//  frame at the start, to create the same envelope that the REQ socket
//  would normally make for us:

int
mdcli_send (mdcli_t *self, char *service, zmsg_t **request_p)
{
    assert (self);
    assert (request_p);
    zmsg_t *request = *request_p;

    //  Prefix request with protocol frames
    //  Frame 0: empty (REQ emulation)
    //  Frame 1: "MDPCxy" (six bytes, MDP/Client x.y)
    //  Frame 2: Service name (printable string)
    zmsg_pushstr (request, service);
    zmsg_pushstr (request, MDPC_CLIENT);
    zmsg_pushstr (request, "");
    if (self->verbose) {
        zclock_log ("I: send request to '%s' service:", service);
        zmsg_dump (request);
    }
    zmsg_send (&request, self->client);
    return 0;
}

//  .skip
//  The recv method waits for a reply message and returns that to the 
//  caller.
//  ---------------------------------------------------------------------
//  Returns the reply message or NULL if there was no reply. Does not
//  attempt to recover from a broker failure, this is not possible
//  without storing all unanswered requests and resending them all...

zmsg_t *
mdcli_recv (mdcli_t *self)
{
    assert (self);

    //  Poll socket for a reply, with timeout
    zmq_pollitem_t items [] = { { self->client, 0, ZMQ_POLLIN, 0 } };
    int rc = zmq_poll (items, 1, self->timeout * ZMQ_POLL_MSEC);
    if (rc == -1)
        return NULL;            //  Interrupted

    //  If we got a reply, process it
    if (items [0].revents & ZMQ_POLLIN) {
        zmsg_t *msg = zmsg_recv (self->client);
        if (self->verbose) {
            zclock_log ("I: received reply:");
            zmsg_dump (msg);
        }
        //  Don't try to handle errors, just assert noisily
        assert (zmsg_size (msg) >= 4);

        zframe_t *empty = zmsg_pop (msg);
        assert (zframe_streq (empty, ""));
        zframe_destroy (&empty);

        zframe_t *header = zmsg_pop (msg);
        assert (zframe_streq (header, MDPC_CLIENT));
        zframe_destroy (&header);

        zframe_t *service = zmsg_pop (msg);
        zframe_destroy (&service);

        return msg;     //  Success
    }
    if (zctx_interrupted)
        printf ("W: interrupt received, killing client...\n");
    else
    if (self->verbose)
        zclock_log ("W: permanent error, abandoning request");

    return NULL;
}
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

~~~{caption="mdclient2: Majordomo client application in C"}
//  Majordomo Protocol client example - asynchronous
//  Uses the mdcli API to hide all MDP aspects

//  Lets us build this source without creating a library
#include "mdcliapi2.c"

int main (int argc, char *argv [])
{
    int verbose = (argc > 1 && streq (argv [1], "-v"));
    mdcli_t *session = mdcli_new ("tcp://localhost:5555", verbose);

    int count;
    for (count = 0; count < 100000; count++) {
        zmsg_t *request = zmsg_new ();
        zmsg_pushstr (request, "Hello world");
        mdcli_send (session, "echo", &request);
    }
    for (count = 0; count < 100000; count++) {
        zmsg_t *reply = mdcli_recv (session);
        if (reply)
            zmsg_destroy (&reply);
        else
            break;              //  Interrupted by Ctrl-C
    }
    printf ("%d replies received\n", count);
    mdcli_destroy (&session);
    return 0;
}
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

~~~{caption="mmiecho: Service discovery over Majordomo in C"}
//  MMI echo query example

//  Lets us build this source without creating a library
#include "mdcliapi.c"

int main (int argc, char *argv [])
{
    int verbose = (argc > 1 && streq (argv [1], "-v"));
    mdcli_t *session = mdcli_new ("tcp://localhost:5555", verbose);

    //  This is the service we want to look up
    zmsg_t *request = zmsg_new ();
    zmsg_addstr (request, "echo");

    //  This is the service we send our request to
    zmsg_t *reply = mdcli_send (session, "mmi.service", &request);

    if (reply) {
        char *reply_code = zframe_strdup (zmsg_first (reply));
        printf ("Lookup echo service: %s\n", reply_code);
        free (reply_code);
        zmsg_destroy (&reply);
    }
    else
        printf ("E: no response from broker, make sure it's running\n");

    mdcli_destroy (&session);
    return 0;
}
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
