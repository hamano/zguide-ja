# 基礎
## 世界の修正
;How to explain ØMQ? Some of us start by saying all the wonderful things it does. It's sockets on steroids. It's like mailboxes with routing. It's fast! Others try to share their moment of enlightenment, that zap-pow-kaboom satori paradigm-shift moment when it all became obvious. Things just become simpler. Complexity goes away. It opens the mind. Others try to explain by comparison. It's smaller, simpler, but still looks familiar. Personally, I like to remember why we made ØMQ at all, because that's most likely where you, the reader, still are today.

さてどうやってØMQを説明しましょうか。
私達の中には、素晴らしい事柄を並べて説明を始める人もいます。
それはソケットのステロイド化合物だ。それはメールボックスのルーティングの様だ。それは速い!
その他にはzap-pow-kaboomパラダイムシフトの悟りを開き、全てが明解になる瞬間を共有しようとする人もいます。
物事は単純になります。複雑さは消え、心を開くのです…

もっと他の説明を試してみましょう。こちらは短くて単純ですがもっと馴染みやすいはずです。
個人的に何故私達がØMQを作ったかという話を覚えておいて欲しいです。
何故かというと、ほとんどの読者も同じ問題を抱えているはずだからです。

;Programming is science dressed up as art because most of us don't understand the physics of software and it's rarely, if ever, taught. The physics of software is not algorithms, data structures, languages and abstractions. These are just tools we make, use, throw away. The real physics of software is the physics of people—specifically, our limitations when it comes to complexity, and our desire to work together to solve large problems in pieces. This is the science of programming: make building blocks that people can understand and use easily, and people will work together to solve the very largest problems.

プログラミングは芸術としてドレスアップされた理学です。私達のほとんどはこれまで教わったことがないために、ソフトウェアの物理学を理解していません。
ソフトウェアの物理学とはアルゴリズムやデータ構造、言語、抽象化などではありません。
それらは唯の道具であり、作って使い捨てるものです。
本当のソフトウェアの物理学とは人間の物理学です。
具体的には、複雑性による私達の限界や巨大な問題を解決したいという欲求です。
人々が簡単に理解して利用できるブロックを作り、協調して大きな問題を解決する事こそがプログラミングの理学です。

;We live in a connected world, and modern software has to navigate this world. So the building blocks for tomorrow's very largest solutions are connected and massively parallel. It's not enough for code to be "strong and silent" any more. Code has to talk to code. Code has to be chatty, sociable, well-connected. Code has to run like the human brain, trillions of individual neurons firing off messages to each other, a massively parallel network with no central control, no single point of failure, yet able to solve immensely difficult problems. And it's no accident that the future of code looks like the human brain, because the endpoints of every network are, at some level, human brains.

私達は接続された世界に住んでいて、現代のソフトウェアはこの世界を往来しなければなりません。
ですから、ブロックは明日には巨大なシステムに接続され、大量に平行化されるかもしれないのです。
コードは強く物静かであるだけでは不十分です。
コードはコードと会話し、社交的なおしゃべりでなくてはなりません。
コードは人間の脳にある何兆もの独立したニューロンの様にお互いにメッセージを発し、中央制御が必要なく、単一障害点の存在しない超並列ネットワークを構成して動作しなければなりません。そうしてやっと、困難な問題を解決できるようになります。
この様なコードの未来が人間の脳と似ていることは偶然ではありません。
ネットワークのエンドポイントは幾つかのレベルで人間の脳と同じだからです。

;If you've done any work with threads, protocols, or networks, you'll realize this is pretty much impossible. It's a dream. Even connecting a few programs across a few sockets is plain nasty when you start to handle real life situations. Trillions? The cost would be unimaginable. Connecting computers is so difficult that software and services to do this is a multi-billion dollar business.

この様なシステムをスレッドやプロトコル、ネットワークを1から構築して実装しようとした場合、到底不可能であることに気がつくでしょう。それは夢物語です。
複数のプログラムが複数のソケットを利用して接続するプログラムは現実的には地味に厄介です。
想像を絶するコストが掛かります。
数十億ドル規模のビジネスでコンピューターを接続するソフトウェアやサービスを行うことは非常に困難になります。

;So we live in a world where the wiring is years ahead of our ability to use it. We had a software crisis in the 1980s, when leading software engineers like Fred Brooks believed there was no "Silver Bullet" to "promise even one order of magnitude of improvement in productivity, reliability, or simplicity".

私達は自分たちの扱える能力に見合った世界で生活しています。
1980年代にソフトウェア業界の重大局面がありました。
フレデリック・ブルックスのような有名ソフトウェア・エンジニアが生産性、信頼性、単純性を大幅に改善する[「銀の弾など存在しない」](http://en.wikipedia.org/wiki/No_Silver_Bullet)と断言した事です。

;Brooks missed free and open source software, which solved that crisis, enabling us to share knowledge efficiently. Today we face another software crisis, but it's one we don't talk about much. Only the largest, richest firms can afford to create connected applications. There is a cloud, but it's proprietary. Our data and our knowledge is disappearing from our personal computers into clouds that we cannot access and with which we cannot compete. Who owns our social networks? It is like the mainframe-PC revolution in reverse.

ブルックスはオープンソースソフトウェアが効果的に知識を共有するする事を可能にして重大局面を解決することを見落としていました。
そして現在、ソフトウェア業界は別の重大局面に直面していますがこれについて話したがる人はあまり居ません。
最も巨大で裕福な企業のみが、接続するアプリケーションを開発する余裕があります。
それはプロプライエタリなクラウドです。
我々のデータと知識はパーソナルコンピューターの中からクラウドの中に消えてしまい、我々自身もアクセス出来なくなっています。
ソーシャルネットワークを自分自身で所有している人はいますか?
これではまるでメインフレーム-パーソナルコンピューター革命を逆行しているようです。

;We can leave the political philosophy for another book. The point is that while the Internet offers the potential of massively connected code, the reality is that this is out of reach for most of us, and so large interesting problems (in health, education, economics, transport, and so on) remain unsolved because there is no way to connect the code, and thus no way to connect the brains that could work together to solve these problems.

政治哲学的な話はこの辺にしておいて[他の本](http://swsi.info/)に譲る事にしますが、重要なのはインターネットは潜在的に大量のコードが接続しあうにも関わらず、現実では私達の手の届かない所にあるという事です。
そしてこれは健康、教育、経済、流通などにおいて非常に興味深い問題を引き起こしますが、コードを接続する方法が無いので未だ解決出来ていません。
したがって、これらの問題を解決するには脳を接続出来る相手と一緒に仕事するしかありません。

;There have been many attempts to solve the challenge of connected code. There are thousands of IETF specifications, each solving part of the puzzle. For application developers, HTTP is perhaps the one solution to have been simple enough to work, but it arguably makes the problem worse by encouraging developers and architects to think in terms of big servers and thin, stupid clients.

コードを接続するという問題に関して多くの試みが行われてきました。
何千ものIETFの仕様はこれらの問題を解決するパズルの一部です。
HTTPは恐らくアプリケーション開発者にとって単純明解な解決方法の一つでしょう。しかしそれは楽観的な開発者や設計者による、巨大なサーバーと貧弱なクライアントを前提とした考えであり、問題を悪化させるでしょう。

;So today people are still connecting applications using raw UDP and TCP, proprietary protocols, HTTP, and Websockets. It remains painful, slow, hard to scale, and essentially centralized. Distributed P2P architectures are mostly for play, not work. How many applications use Skype or Bittorrent to exchange data?

そして現在でも人々はUDPやTCP、プロプライエタリなプロトコル、HTTP、Webソケットを使用してアプリケーションを接続しています。
それは痛みを伴うほど遅く、拡張が難しく、本質的に中央集中型です。
分散P2Pはほとんど娯楽のためであり、ビジネスで使うには難しいでしょう。
SkypeやBittorrentとデータ通信を行うアプリケーションがどれほどあるでしょうか?

;Which brings us back to the science of programming. To fix the world, we needed to do two things. One, to solve the general problem of "how to connect any code to any code, anywhere". Two, to wrap that up in the simplest possible building blocks that people could understand and use easily.

プログラミングの理学の話に立ち帰ると、世界を修正するために我々は2つの事を行う必要があります。
1つ目は「何処でもコードとコードを接続出来るようにする方法」という一般的な問題を解決すること。
2つ目は人々が簡単に理解して利用できる単純なブロックでそれを包み込む事です。

;It sounds ridiculously simple. And maybe it is. That's kind of the whole point.

それは馬鹿馬鹿しいほど単純に聞こえるし、多分きっとそうなんでしょう。
しかしこれはとても肝心な事です。

## 前提条件
;We assume you are using at least version 3.2 of ØMQ. We assume you are using a Linux box or something similar. We assume you can read C code, more or less, as that's the default language for the examples. We assume that when we write constants like PUSH or SUBSCRIBE, you can imagine they are really called ZMQ_PUSH or ZMQ_SUBSCRIBE if the programming language needs it.

あなたが最新のØMQ バージョン 3.2を利用している事を想定しています。
また、あなたがLinuxマシンまたは類似の何かを利用していることを想定します。
サンプルコードの既定の言語はC言語ですので、あなたが多かれ少なかれC言語が読めることを想定しています。
私が`PUSH`や`SUBSCRIBE`といった定数を書いた時、実際には`ZMQ_PUSH`や`ZMQ_SUBSCRIBE` という様に各プログラミング言語で使われる記述に読み替えて読んでください。

## サンプルコードの取得
;The examples live in a public GitHub repository. The simplest way to get all the examples is to clone this repository:

サンプルコードは[GitHubの公開レポジトリ](https://github.com/imatix/zguide)から取得できます。
全てのサンプルコードを取得する最も簡単な方法はレポジトリをcloneすることです。

~~~
git clone --depth=1 git://github.com/imatix/zguide.git
~~~

;Next, browse the examples subdirectory. You'll find examples by language. If there are examples missing in a language you use, you're encouraged to submit a translation. This is how this text became so useful, thanks to the work of many people. All examples are licensed under MIT/X11.

続いてexamplesサブディレクトリを参照すると、プログラミング言語毎のディレクトリ見つけるでしょう。
もしあなたのお気に入りのプログラミング言語が無い場合はコードを移植して送って頂ください。
この様に多くの人々の協力でこのテキストは便利になりました。
全てのサンプルコードはMIT/X11ライセンスで公開されています。

## 尋ねよ、さらば受け取らん
;So let's start with some code. We start of course with a Hello World example. We'll make a client and a server. The client sends "Hello" to the server, which replies with "World". Here's the server in C, which opens a ØMQ socket on port 5555, reads requests on it, and replies with "World" to each request:

さあ、コードから始めましょう。
もちろん最初はHello Worldのサンプルコードから始めます。
クライアントが「Hello」をサーバーに送信したら、サーバーは「World」を応答するクライアントとサーバーを作ってみましょう。
ここでサーバーはØMQソケットをTCPポート5555番で待ち受け、リクエストを受け取ったら「World」を応答するコードをC言語で実装しています:

~~~ {caption="hwserver: Hello Worldサーバー"}
include(examples/EXAMPLE_LANG/hwserver.EXAMPLE_EXT)
~~~

![リクエストと応答](images/fig2.eps)

;The REQ-REP socket pair is in lockstep. The client issues zmq_send() and then zmq_recv(), in a loop (or once if that's all it needs). Doing any other sequence (e.g., sending two messages in a row) will result in a return code of -1 from the send or recv call. Similarly, the service issues zmq_recv() and then zmq_send() in that order, as often as it needs to.

REQ-REPソケットペアはロックステップ方式です。
クライアントはループ内で`zmq_send()`を呼んでから`zmq_recv()`を発行します。
それ以外のケース、例えば2回メッセージを送信した場合などでは`zmq_send()`や`zmq_recv()`で-1が返ります。
同様にサーバー側は`zmq_recv()`を呼んでから`zmq_send()`を発行する必要があります。

;ØMQ uses C as its reference language and this is the main language we'll use for examples. If you're reading this online, the link below the example takes you to translations into other programming languages. Let's compare the same server in C++:

ØMQはリファレンス言語としてC言語を採用しているので、サンプルコードでもC言語を使います。
ここではC++のコードを見て比べてみましょう。

~~~ {caption="hwserver.cpp: Hello Worldサーバー"}
//
// Hello Worldサーバー(C++版)
// REPソケットをtcp://*:5555 でバインドします。
// クライアントが"Hello"を送信してきた時、"World"と応答します。
//
#include <zmq.hpp>
#include <string>
#include <iostream>
#ifndef _WIN32
#include <unistd.h>
#else
#include <windows.h>
#endif

int main () {
    // コンテキストとソケットの準備
    zmq::context_t context (1);
    zmq::socket_t socket (context, ZMQ_REP);
    socket.bind ("tcp://*:5555");

    while (true) {
        zmq::message_t request;

        // クライアントからのリクエストを待機
        socket.recv (&request);
        std::cout << "Received Hello" << std::endl;

        // 何らかの処理
#ifndef _WIN32
    sleep(1);
#else
    Sleep (1);
#endif

        // クライアントに応答
        zmq::message_t reply (5);
        memcpy ((void *) reply.data (), "World", 5);
        socket.send (reply);
    }
    return 0;
}
~~~

;You can see that the ØMQ API is similar in C and C++. In a language like PHP or Java, we can hide even more and the code becomes even easier to read:

ØMQのAPIはC言語とC++でほとんど同じだという事が解ると思います。
PHPとJavaの例も見てみましょう。

~~~ {caption="hwserver.php: Hello Worldサーバー"}
<?php
/*
* Hello Worldサーバー(PHP)
* REPソケットをtcp://*:5555 でバインドします。
* クライアントが"Hello"を送信してきた時、"World"と応答します。
* @author Ian Barber <ian(dot)barber(at)gmail(dot)com>
*/

$context = new ZMQContext(1);

// クライアントとの通信ソケット
$responder = new ZMQSocket($context, ZMQ::SOCKET_REP);
$responder->bind("tcp://*:5555");

while (true) {
    // クライアントカアラのリクエストを待機
    $request = $responder->recv();
    printf ("Received request: [%s]\n", $request);

    // 何らかの処理
    sleep (1);

    // クライアントに応答
    $responder->send("World");
}
~~~

~~~ {caption="hwserver.java: Hello Worldサーバー"}
//
// Hello Worldサーバー(Java)
// REPソケットをtcp://*:5555 でバインドします。
// クライアントが"Hello"を送信してきた時、"World"と応答します。
//

import org.zeromq.ZMQ;

public class hwserver{

    public static void main (String[] args) throws Exception{
        ZMQ.Context context = ZMQ.context(1);
        // クライアントとの通信ソケット
        ZMQ.Socket socket = context.socket(ZMQ.REP);
        socket.bind ("tcp://*:5555");

        while (!Thread.currentThread ().isInterrupted ()) {
            byte[] reply = socket.recv(0);
            System.out.println("Received Hello");
            Thread.sleep(1000); // 何らかの処理
            String request = "World" ;
            socket.send(request.getBytes (), 0);
        }
        socket.close();
        context.term();
    }
}
~~~

;Here's the client code:

以下はクライアントのコードです。

~~~ {caption="hwclient: Hello Worldクライアント"}
include(examples/EXAMPLE_LANG/hwclient.EXAMPLE_EXT)
~~~

;Now this looks too simple to be realistic, but ØMQ sockets have, as we already learned, superpowers. You could throw thousands of clients at this server, all at once, and it would continue to work happily and quickly. For fun, try starting the client and then starting the server, see how it all still works, then think for a second what this means.

さて、この例は現実的にあまりにも単純に見えますが、これまで学んできたようにØMQソケットはとんでもない力を秘めています。
あなたは同時に数千のクライアントでこのサーバーに接続することができ、問題なく迅速に動作し続けるでしょう。
戯れにサーバーを立ち上げてクライアントを実行し、どんな風に動作するか試してみてください。
そしてこの意味を少し考えてみて下さい。

;Let us explain briefly what these two programs are actually doing. They create a ØMQ context to work with, and a socket. Don't worry what the words mean. You'll pick it up. The server binds its REP (reply) socket to port 5555. The server waits for a request in a loop, and responds each time with a reply. The client sends a request and reads the reply back from the server.

これら2つのプログラムが実際に何をしているか簡潔に説明しましょう。
これらはまずØMQコンテキストとØMQソケットを作成します。言葉の意味については後で説明しますのでまだ心配しなくて大丈夫です。サーバーはREP(応答)ソケットをポート5555番でbindします。サーバーはループの中でリクエストを待ち、リクエスト毎に応答します。
クライアントはリクエストを送信し、サーバーからの応答を受け取ります。

;If you kill the server (Ctrl-C) and restart it, the client won't recover properly. Recovering from crashing processes isn't quite that easy. Making a reliable request-reply flow is complex enough that we won't cover it until Chapter 4 - Reliable Request-Reply Patterns.

サーバーをCtrl-Cで終了して再起動した場合、クライアントは適切に復旧しません。
プロセスの異常終了から復旧することは簡単ではありません。
信頼性の高いリクエスト-応答フローを構成することは十分複雑なので、これについては4章の「信頼性のあるリクエスト・応答パターン」で説明します。

;There is a lot happening behind the scenes but what matters to us programmers is how short and sweet the code is, and how often it doesn't crash, even under a heavy load. This is the request-reply pattern, probably the simplest way to use ØMQ. It maps to RPC and the classic client/server model.

我々プログラマにとってどんなに短く素敵なコードでも、裏側ではたくさんの事が起こっています。そしてそのおかげでどれだけ負荷を掛けてもクラッシュしません。
これをリクエスト・応答パターンと呼びます。
恐らく、ØMQの最も単純な利用方法です。
これはRPCとか、古典的なクライアント・サーバーモデルに対応します。

## 文字列に関する補足
;ØMQ doesn't know anything about the data you send except its size in bytes. That means you are responsible for formatting it safely so that applications can read it back. Doing this for objects and complex data types is a job for specialized libraries like Protocol Buffers. But even for strings, you need to take care.

ØMQはデータについてサイズ以外の事は何も知りません。
これは、プログラマがアプリケーション側で安全に読み戻せるようにする責任があるという事を意味します。
オブジェクトや複雑なデータ構造を利用する事はProtocol Buffersの様なライブラリの役目です。
文字列でさえ気を配ってやる必要があります。

;In C and some other languages, strings are terminated with a null byte. We could send a string like "HELLO" with that extra null byte:

C言語や幾つかの言語では、文字列はNULL文字で終端してます。
"HELLO"という様な文字列を送信する際、以下の様にNULL文字付きで送信出来ます。

    zmq_send (requester, "Hello", 6, 0);

;However, if you send a string from another language, it probably will not include that null byte. For example, when we send that same string in Python, we do this:

しかしながらその他の言語ではNULL文字を含まない場合があります。
例えばPythonでは、以下のようにして文字列を送信します。

    socket.send ("Hello")

;Then what goes onto the wire is a length (one byte for shorter strings) and the string contents as individual characters.

この時、文字列の長さと文字列の内容がネットワーク上を流れます。

![ØMQ文字列](images/fig3.eps)

;And if you read this from a C program, you will get something that looks like a string, and might by accident act like a string (if by luck the five bytes find themselves followed by an innocently lurking null), but isn't a proper string. When your client and server don't agree on the string format, you will get weird results.

そしてもしC言語のプログラムでこれを読むと、あなたは偶然文字列の様なものを受け取るでしょうが、これは正しい文字列ではありません。
クライアントとサーバーで文字列フォーマットに関する合意がない場合、おかしな結果が得られるかもしれません。

;When you receive string data from ØMQ in C, you simply cannot trust that it's safely terminated. Every single time you read a string, you should allocate a new buffer with space for an extra byte, copy the string, and terminate it properly with a null.

C言語で文字列を受信する際、文字列が安全にNULL終端していると期待してはいけません。
文字列を読み込む際には、新たに大きめの新しくバッファを確保し、コピーして適切にNULL文字で終端させてやる必要があります。

;So let's establish the rule that ØMQ strings are length-specified and are sent on the wire without a trailing null. In the simplest case (and we'll do this in our examples), a ØMQ string maps neatly to a ØMQ message frame, which looks like the above figure—a length and some bytes.

それでは、*NULL終端していないØMQ文字列が送られてきた場合*のルールを確立しましょう。
最も単純なケースでは、先の図の様にØMQ文字列の長さと内容はØMQメッセージフレームにぴったり一致します。

;Here is what we need to do, in C, to receive a ØMQ string and deliver it to the application as a valid C string:

以下のコードは、C言語で受け取ったØMQ文字列を適切な文字列としてアプリケーションに受け渡す為に何を行う必要があるのかを示しています。

~~~
// ソケットから0MQ文字列を受信してC文字列に変換する
// 255文字より長い文字列は打ち切る
static char *
s_recv (void *socket) {
    char buffer [256];
    int size = zmq_recv (socket, buffer, 255, 0);
    if (size == -1)
        return NULL;
    if (size > 255)
        size = 255;
    buffer [size] = 0;
    return strdup (buffer);
}
~~~

;This makes a handy helper function and in the spirit of making things we can reuse profitably, let's write a similar s_send function that sends strings in the correct ØMQ format, and package this into a header file we can reuse.

モノ作り精神で作成したこの便利なヘルパー関数は有効に再利用することが出来ます。
同様に、正しいØMQフォーマット文字列を送信するs_send関数も書いてみましょう。
そして再利用できるヘッダーファイルをパッケージングします。

;The result is zhelpers.h, which lets us write sweeter and shorter ØMQ applications in C. It is a fairly long source, and only fun for C developers, so read it at leisure.

その成果がzhelpers.hであり、これによって短く簡潔にØMQアプリケーションを書くことが出来ます。
このソースコードは相当長いですが、興味があるC開発者の方は余裕がある時に読んでみて下さい。

## バージョン報告
;ØMQ does come in several versions and quite often, if you hit a problem, it'll be something that's been fixed in a later version. So it's a useful trick to know exactly what version of ØMQ you're actually linking with.

ØMQには幾つかのバージョンがあり、頻繁にバージョンアップします。
もし問題に遭遇したとしても最新のバージョンで修正されていることが多いでしょう。
ですからØMQのバージョンを正確に調べる方法を知っておくと役に立ちます。

;Here is a tiny program that does that:

以下はそれを行う小さなプログラムです:

~~~ {caption="version: ØMQのバージョン報告"}
include(examples/EXAMPLE_LANG/version.EXAMPLE_EXT)
~~~

## メッセージ配信
;The second classic pattern is one-way data distribution, in which a server pushes updates to a set of clients. Let's see an example that pushes out weather updates consisting of a zip code, temperature, and relative humidity. We'll generate random values, just like the real weather stations do.

第二の典型的なパターンは、サーバーから複数のクライアントに更新をプッシュする一方方向のデータ配信です。
それでは、郵便番号と気温、湿度からなる気象情報をプッシュ配信する例を見てみましょう。
ここで利用する気象情報はランダムに生成した値を利用することにします。

;Here's the server. We'll use port 5556 for this application:

以下がサーバーのサンプルコードです。このアプリケーションはTCP 5556番ポートを利用します。

~~~ {caption="wuserver: 気象情報更新サーバー"}
include(examples/EXAMPLE_LANG/wuserver.EXAMPLE_EXT)
~~~

;There's no start and no end to this stream of updates, it's like a never ending broadcast.

終わりの無い放送の様に、このストリームの配信に始まりと終わりはありません。

;Here is the client application, which listens to the stream of updates and grabs anything to do with a specified zip code, by default New York City because that's a great place to start any adventure:

以下のクライアントアプリケーションはストリームの配信を聞き取り、特定の郵便番号に関するデータを収集します。デフォルトではニューヨークを指定しています。なぜならそこは冒険を始めるには絶好の場所だからです。

~~~ {caption="wuclient: 気象情報更新クライアント"}
include(examples/EXAMPLE_LANG/wuclient.EXAMPLE_EXT)
~~~

![パブリッシュ・サブスクライブ](images/fig4.eps)

;Note that when you use a SUB socket you must set a subscription using zmq_setsockopt() and SUBSCRIBE, as in this code. If you don't set any subscription, you won't get any messages. It's a common mistake for beginners. The subscriber can set many subscriptions, which are added together. That is, if an update matches ANY subscription, the subscriber receives it. The subscriber can also cancel specific subscriptions. A subscription is often, but not necessarily a printable string. See zmq_setsockopt() for how this works.

SUBソケットを利用する際、このコードの様に`zmq_setsockopt()`で`SUBSCRIBE`を*設定しなければならない*ことに注意して下さい。もし設定しなかった場合メッセージを受信できません。これはよくある初歩的なミスです。サブスクライバーは複数のサブスクリプションを設定できます。その際サブスクリプションに一致した更新のみ受信します。
サブスクライバーは特定のサブスクリプションをキャンセルすることも出来ます。
サブスクリプションは必ずしも印字可能な文字とは限りません。
これがどの様に動作するかは`zmq_setsockopt()`のソースコードを読んで下さい。

;The PUB-SUB socket pair is asynchronous. The client does zmq_recv(), in a loop (or once if that's all it needs). Trying to send a message to a SUB socket will cause an error. Similarly, the service does zmq_send() as often as it needs to, but must not do zmq_recv() on a PUB socket.

PUB-SUBソケットのペアは非同期で動作し、通常クライアントはループ内で`zmq_recv()`を呼び出します。
SUBソケットでメッセージを送信しようとするとエラーが発生します。
同様に、PUBソケットで`zmq_recv()`を呼んではいけません。

;In theory with ØMQ sockets, it does not matter which end connects and which end binds. However, in practice there are undocumented differences that I'll come to later. For now, bind the PUB and connect the SUB, unless your network design makes that impossible.

理論上はどちらがbindしてどちらが接続しても問題ないはずです。
しかし今の所ドキュメント化されていないので出来ればPUBでbindしてSUBで接続して下さい。

;There is one more important thing to know about PUB-SUB sockets: you do not know precisely when a subscriber starts to get messages. Even if you start a subscriber, wait a while, and then start the publisher, the subscriber will always miss the first messages that the publisher sends. This is because as the subscriber connects to the publisher (something that takes a small but non-zero time), the publisher may already be sending messages out.

PUB-SUBソケットについて知るべき重要なことがもうひとつあります。
それは、サブスクライバーがいつメッセージを受信し始めたかどうかを正確に知ることは出来ないという事です。
サブスクライバーを起動し、しばらく経ってパブリッシャーを起動した場合でも*必ず最初のメッセージを取りこぼします*。
これは、サブスクライバがパブリッシャーに接続している間(一瞬だがゼロでは無い時間)に、パブリッシャーがメッセージを配信している可能性が在るからです。

;This "slow joiner" symptom hits enough people often enough that we're going to explain it in detail. Remember that ØMQ does asynchronous I/O, i.e., in the background. Say you have two nodes doing this, in this order:

多くの人がこの「参加遅延症状」に遭遇するので私達はこれについての説明を頻繁に行います。
ØMQが非同期I/Oであることを思い出して下さい。
2ノードでこれを行う際、バックグラウンドでは以下の事を以下の順序で行います。

;* Subscriber connects to an endpoint and receives and counts messages.
;* Publisher binds to an endpoint and immediately sends 1,000 messages.

 * サブスクライバはエンドポイントに接続し、メッセージを受信して数える。
 * パブリッシャーはエンドポイントをbindし、即座に1000メッセージを送信する。

;Then the subscriber will most likely not receive anything. You'll blink, check that you set a correct filter and try again, and the subscriber will still not receive anything.

恐らくサブスクライバーは何も受信していないでしょう。
フィルタが正しく設定されているか確認し、再度試してみて下さい。
まだ何も受信出来ていないはずです。

;Making a TCP connection involves to and from handshaking that takes several milliseconds depending on your network and the number of hops between peers. In that time, ØMQ can send many messages. For sake of argument assume it takes 5 msecs to establish a connection, and that same link can handle 1M messages per second. During the 5 msecs that the subscriber is connecting to the publisher, it takes the publisher only 1 msec to send out those 1K messages.

TCPコネクションの作成およびハンドシェイクはネットワークやピア間のホップ数に応じて数ミリ秒の遅延を発生させます。
ØMQはこの間に多くのメッセージを送信できます。
便宜上、コネクションの確立に5ミリ秒かかり、1秒間に100万メッセージを処理できると仮定すると、パブリッシャーはサブスクライバが接続しているわずか5ミリ秒の間に、5000メッセージを送信出来ることになります。

;In Chapter 2 - Sockets and Patterns we'll explain how to synchronize a publisher and subscribers so that you don't start to publish data until the subscribers really are connected and ready. There is a simple and stupid way to delay the publisher, which is to sleep. Don't do this in a real application, though, because it is extremely fragile as well as inelegant and slow. Use sleeps to prove to yourself what's happening, and then wait for Chapter 2 - Sockets and Patterns to see how to do this right.

「2章 ソケットとパターン」ではパブリッシャーとサブスクライバを同期してサブスクライバの準備が整うまでパブリッシャーがデータを配信しないようにする方法を説明します。
単純にsleepを入れて遅延させるという愚直な方法もありますが、実用のアプリケーションでこれをやると極めて不安定な上に遅いのでやらないで下さい。
正しくこれをやる方法と、sleepを行うと何が起こるかは「2章 ソケットとパターン」まで待って下さい。

;The alternative to synchronization is to simply assume that the published data stream is infinite and has no start and no end. One also assumes that the subscriber doesn't care what transpired before it started up. This is how we built our weather client example.

同期を行わない場合、サーバーは無限にデータを配信することを前提とし、サブスクライバは開始時に始まりと終わりを扱いません。
これは天気クライアントの例で見てきた通りです。

;So the client subscribes to its chosen zip code and collects 100 updates for that zip code. That means about ten million updates from the server, if zip codes are randomly distributed. You can start the client, and then the server, and the client will keep working. You can stop and restart the server as often as you like, and the client will keep working. When the client has collected its thousand updates, it calculates the average, prints it, and exits.

まとめると、クライアントは指定した郵便番号の更新を100個収集します。
郵便番号がランダムに分布している場合には、約1千万の更新が送られてくることになります。
クライアントを開始した後に、サーバを起動してもクライアントは問題なく動作します。
サーバーを好きなタイミングで再起動しても、クライアントは動作し続けます。
クライアントが100の更新を収集すると、平均値を計算し、表示して終了します。

;Some points about the publish-subscribe (pub-sub) pattern:

パブリッシュ・サブスクライブ(PUB-SUB)パターンの要点は以下の通りです。

;* A subscriber can connect to more than one publisher, using one connect call each time. Data will then arrive and be interleaved ("fair-queued") so that no single publisher drowns out the others.
;* If a publisher has no connected subscribers, then it will simply drop all messages.
;* If you're using TCP and a subscriber is slow, messages will queue up on the publisher. We'll look at how to protect publishers against this using the "high-water mark" later.
;* From ØMQ v3.x, filtering happens at the publisher side when using a connected protocol (tcp: or ipc:). Using the epgm:// protocol, filtering happens at the subscriber side. In ØMQ v2.x, all filtering happened at the subscriber side.

 * サブスクライバーは一つ以上のパブリッシャーに接続することが出来ます。一つのパブリッシャーが大量のメッセージを流して専有してしまわないように、到着したデータは制御されています。これを「平衡キューイング」と呼びます。

 * パブリッシャーに接続しているサブスクライバーが居ない時、全てのメッセージは単純に破棄されます。

 * TCPを利用していてサブスクライバが遅い場合、メッセージはパブリッシャーのキューに入れられます。「HWM(満杯マーク)」を利用してパブリッシャーを保護する方法については後で説明します。

 * ØMQ v3.x以降、ステートフルプロトコル(tcp: もしくは ipc:)を利用している場合にパブリッシャー側でフィルタリング出来るようになりました。epgm:// プロトコルを利用する場合は、サブスクライバ側でフィルタリングします。ØMQ v2.xでは全てのフィルタリングはサブスクライバ側で行います。

;This is how long it takes to receive and filter 10M messages on my laptop, which is an 2011-era Intel i5, decent but nothing special:

これは、2011年に買ったIntel i5の普通のノートPCで1千万のメッセージを受信してフィルタリングするのに掛かった時間です。

~~~
$ time wuclient
Collecting updates from weather server...
Average temperature for zipcode '10001 ' was 28F

real    0m4.470s
user    0m0.000s
sys     0m0.008s
~~~

## 分割統治法

![並行パイプライン](images/fig5.eps)

;As a final example (you are surely getting tired of juicy code and want to delve back into philological discussions about comparative abstractive norms), let's do a little supercomputing. Then coffee. Our supercomputing application is a fairly typical parallel processing model. We have:

最後の例は小さなスパコンを作って計算してみましょう。そして沢山のコードばかりを見てきて疲れたでしょうからコーヒーでも飲んで休憩してください。
スパコンのアプリケーションは典型的な並行分散処理モデルです。


;* A ventilator that produces tasks that can be done in parallel
;* A set of workers that process tasks
;* A sink that collects results back from the worker processes

 * 「ベンチレーター」は並行に処理できるタスクを生成します。
 * 「ワーカー」群はタスクを処理します。
 * 「シンク」は「ワーカー」の処理結果を収集します。

;In reality, workers run on superfast boxes, perhaps using GPUs (graphic processing units) to do the hard math. Here is the ventilator. It generates 100 tasks, each a message telling the worker to sleep for some number of milliseconds:

実践ではワーカーはGPUなどを搭載した高速マシンで実行されます。
ベンチレーターは100のタスクを生成しワーカーに送信します。
ワーカーは受け取った数値×ミリ秒のsleepを行います。

~~~ {caption="taskvent: 並行タスクベンチレーター"}
include(examples/EXAMPLE_LANG/taskvent.EXAMPLE_EXT)
~~~

;Here is the worker application. It receives a message, sleeps for that number of seconds, and then signals that it's finished:

以下はワーカーアプリケーションです。
受信したメッセージの秒数分sleepし、完了を通知します。

~~~ {caption="taskwork: 並行タスクワーカー"}
include(examples/EXAMPLE_LANG/taskwork.EXAMPLE_EXT)
~~~

;Here is the sink application. It collects the 100 tasks, then calculates how long the overall processing took, so we can confirm that the workers really were running in parallel if there are more than one of them:

以下はシンクアプリケーションです。
100のタスクを収集し、処理にどれくらいの時間が掛かったかを計算します。
この結果により、本当に並行処理が行われたどうかを確認できます。

~~~ {caption="tasksink: 並行タスクシンク"}
include(examples/EXAMPLE_LANG/tasksink.EXAMPLE_EXT)
~~~

;The average cost of a batch is 5 seconds. When we start 1, 2, or 4 workers we get results like this from the sink:

平均的な実行時間は大体5秒程度です。
ワーカーを1, 2, 4個と増やした時の結果は以下の通りです。

;* 1 worker: total elapsed time: 5034 msecs.
;* 2 workers: total elapsed time: 2421 msecs.
;* 4 workers: total elapsed time: 1018 msecs.

 * 1ワーカー: total elapsed time: 5034 msecs.
 * 2ワーカー: total elapsed time: 2421 msecs.
 * 4ワーカー: total elapsed time: 1018 msecs.

;Let's look at some aspects of this code in more detail:

それでは、もっと詳しくコードの特徴を見ていきましょう。

;* The workers connect upstream to the ventilator, and downstream to the sink. This means you can add workers arbitrarily. If the workers bound to their endpoints, you would need (a) more endpoints and (b) to modify the ventilator and/or the sink each time you added a worker. We say that the ventilator and sink are stable parts of our architecture and the workers are dynamic parts of it.

;* We have to synchronize the start of the batch with all workers being up and running. This is a fairly common gotcha in ØMQ and there is no easy solution. The zmq_connect method takes a certain time. So when a set of workers connect to the ventilator, the first one to successfully connect will get a whole load of messages in that short time while the others are also connecting. If you don't synchronize the start of the batch somehow, the system won't run in parallel at all. Try removing the wait in the ventilator, and see what happens.

;* The ventilator's PUSH socket distributes tasks to workers (assuming they are all connected before the batch starts going out) evenly. This is called load balancing and it's something we'll look at again in more detail.

;* The sink's PULL socket collects results from workers evenly. This is called fair-queuing.

 * ワーカーは上流のベンチレーターと下流のシンクに接続します。これは自由にワーカーを追加できる機能を持っているという事を意味しています。もしワーカーがbindを行ったとすると、ワーカーを追加する度にベンチレーターとシンクの動作を変更しなければなりません。ベンチレーターとシンクがアーキテクチャの固定部品であり、ワーカーは動的な部品であると言えます。

 * 全てのワーカーが起動するまで、処理の開始を同期させる必要があります。これはØMQのよくある落とし穴であり簡単な解決方法はありません。`zmq_connect()`関数はどうしてもある程度の時間がかかってしまいます。複数のワーカーがベンチレーターに接続する際、最初のワーカーが正常に接続してメッセージを受信しても、他のワーカーはまだ接続中の状態になります。何らかの方法で、処理の開始を同期しなければシステムは並行に動作しません。試しにgetcharによる一時停止を削除して、何が起こるか確認してみましょう。

 * ベンチレーターのPUSHソケットはタスクを均等にワーカーに分散します(処理が開始されるまでに全てのワーカーは接続済みであると仮定します)。これはロードバランシングと呼ばれ、詳細は後ほど改めて説明します。

 * シンクのPULLソケットはワーカーからの処理結果を均等に収集します。これは*平衡キューイング*と呼びます。

![平衡キューイング](images/fig6.eps)

;The pipeline pattern also exhibits the "slow joiner" syndrome, leading to accusations that PUSH sockets don't load balance properly. If you are using PUSH and PULL, and one of your workers gets way more messages than the others, it's because that PULL socket has joined faster than the others, and grabs a lot of messages before the others manage to connect. If you want proper load balancing, you probably want to look at the The load balancing pattern in Chapter 3 - Advanced Request-Reply Patterns.

この様なパターンで「参加遅延病」が発症した場合、PUSHソケットが適切にロードバランスしなくなる現象を引き起こします。
PUSHとPULLを利用している場合、あるワーカーが他のワーカーより多くのメッセージを受け取ることになります。なぜならばあるPULLソケットは早く接続していて、その他のソケットが接続している間に多くのメッセージを受け取るからです。もし正確なロードバランシングを行いたい場合は「第3章 - Advanced Request-Reply Patterns」を参照して下さい。

## ØMQプログラミング
;Having seen some examples, you must be eager to start using ØMQ in some apps. Before you start that, take a deep breath, chillax, and reflect on some basic advice that will save you much stress and confusion.

幾つかのサンプルコードを見てきました。あなたはØMQでなにかアプリケーションを作りたくて仕方が無いのでしょう。
それを始める前に、大きく深呼吸をして落ち着き、ストレスと混乱を避けるために幾つかの基本的なアドバイスに耳を傾けて下さい。

;* Learn ØMQ step-by-step. It's just one simple API, but it hides a world of possibilities. Take the possibilities slowly and master each one.
;* Write nice code. Ugly code hides problems and makes it hard for others to help you. You might get used to meaningless variable names, but people reading your code won't. Use names that are real words, that say something other than "I'm too careless to tell you what this variable is really for". Use consistent indentation and clean layout. Write nice code and your world will be more comfortable.
;* Test what you make as you make it. When your program doesn't work, you should know what five lines are to blame. This is especially true when you do ØMQ magic, which just won't work the first few times you try it.
;* When you find that things don't work as expected, break your code into pieces, test each one, see which one is not working. ØMQ lets you make essentially modular code; use that to your advantage.
;* Make abstractions (classes, methods, whatever) as you need them. If you copy/paste a lot of code, you're going to copy/paste errors, too.

 * 一歩ずつØMQを学んで下さい。これはとてもシンプルなAPIですが、あらゆる可能性が潜んでいます。起こりうる可能性を一つずつ学んでいってください。

 * 素敵なコードを書いて下さい。醜いコードは問題を隠蔽し、他の人があなたを助けることを困難にします。変数名に無意味な名前を利用すると誰もあなたのコードを読めなくなるでしょう。変数の意味を伝えるのに適切な現実の世界の言葉を使って下さい。一貫したインデントと綺麗なレイアウトを使って下さい。素敵なコードを書くとあなたの世界はより快適になります。

 * あなたが作ったものをテストして下さい。プログラムが動作しない時は何処に原因があるか特定する必要があります。ØMQを初めて使い始めたばかりで上手く動作しない時は特に十分テストして下さい。

 * 上手く動作しない所を見つけた時、個別にテストして切り分けを行って下さい。ØMQは基本的なモジュールコードを作成できます。これはあなたの助けになるでしょう。

 * 必要に応じてコードを上手く抽象化して下さい。同じコードをコピー&ペーストばかりしていたら、エラー箇所も増えてゆきます。

### 正しくコンテキストを取得する
;ØMQ applications always start by creating a context, and then using that for creating sockets. In C, it's the zmq_ctx_new() call. You should create and use exactly one context in your process. Technically, the context is the container for all sockets in a single process, and acts as the transport for inproc sockets, which are the fastest way to connect threads in one process. If at runtime a process has two contexts, these are like separate ØMQ instances. If that's explicitly what you want, OK, but otherwise remember:

ØMQアプリケーションは常にコンテキストを作成し、それを利用してソケットを作成します。
C言語では`zmq_ctx_new()`を呼び出します。
プロセス内に一つのコンテキストを作成し、それを利用します。
技術的に言うと、コンテキストは単一プロセス内で全てのソケットをまとめるコンテナであり、プロセス内で高速にスレッド間を接続するプロセス内ソケットとして振る舞います。
もし、1つの実行プロセスが2つのコンテキスト持つと、それはØMQインスタンスが2に分離しているように見えます。
あえてこうしたいのであれば問題ありませんが、そうでないのなら注意して下さい。

;*Do one zmq_ctx_new() at the start of your main line code, and one zmq_ctx_destroy() at the end.*

*メインコードの最初で* `zmq_ctx_new()` *呼び出して、終わりに* `zmq_ctx_destroy()` *を呼び出して下さい。*

;If you're using the fork() system call, each process needs its own context. If you do zmq_ctx_new() in the main process before calling fork(), the child processes get their own contexts. In general, you want to do the interesting stuff in the child processes and just manage these from the parent process.

`fork()`システムコールを利用している場合、各プロセスは独自のコンテキストを必要とします。
メインプロセスで`zmq_ctx_new()`を呼び出した後に`fork()`した場合、子プロセスは独自のコンテキストを得ます。一般的に、主な処理は子プロセスで行い、親プロセスは子プロセスを管理するだけでしょう。

### 正しく終了する
;Classy programmers share the same motto as classy hit men: always clean-up when you finish the job. When you use ØMQ in a language like Python, stuff gets automatically freed for you. But when using C, you have to carefully free objects when you're finished with them or else you get memory leaks, unstable applications, and generally bad karma.

一流のプログラマは一流の殺し屋と同じ教訓を共有します。「仕事が終わったら後片付けしろ」という事です。
ØMQをPythonの様な言語で利用している場合、オブジェクトは自動的に開放されます。
しかし、C言語の場合は慎重にオブジェクトを開放する必要があります。
そうしなければメモリリークが発生したり、アプリケーションが不安定になったり、天罰が下ったりします。

;Memory leaks are one thing, but ØMQ is quite finicky about how you exit an application. The reasons are technical and painful, but the upshot is that if you leave any sockets open, the zmq_ctx_destroy() function will hang forever. And even if you close all sockets, zmq_ctx_destroy() will by default wait forever if there are pending connects or sends unless you set the LINGER to zero on those sockets before closing them.

メモリリークもその一つです。
ØMQはアプリケーションを終了することに関してとても気難しいです。
その理由は、技術的かつ痛みを伴いますが、もしソケットをオープンしたまま`zmq_ctx_destroy()`関数を呼び出した場合、永久にハングします。
そしてもし、LINGERを0に設定せずに全てのソケットクローズした場合でも、`zmq_ctx_destroy()`で待たされるでしょう。

;The ØMQ objects we need to worry about are messages, sockets, and contexts. Luckily it's quite simple, at least in simple programs:

ØMQで気配りする必要があるオブジェクトはメッセージとソケットとコンテキストの3つです。
幸いなことに、単純なプログラムでこれらを扱うのはとても簡単です。

;* Use zmq_send() and zmq_recv() when you can, as it avoids the need to work with zmq_msg_t objects.
;* If you do use zmq_msg_recv(), always release the received message as soon as you're done with it, by calling zmq_msg_close().
;* If you are opening and closing a lot of sockets, that's probably a sign that you need to redesign your application. In some cases socket handles won't be freed until you destroy the context.
;* When you exit the program, close your sockets and then call zmq_ctx_destroy(). This destroys the context.

 * 可能な限り`zmq_send()`と`zmq_recv()`を使って下さい。これらはzmq_msg_tオブジェクトの利用を避けることが出来ます。
 * `zmq_msg_recv()`を使う場合、メッセージを受信したら`zmq_msg_close()`を呼ぶ前に出来るだけ早く開放して下さい。
 * 多くのソケットをオープンしてクローズする場合、アプリケーションを再設計する必要性がある兆候です。幾つかのケースでは、コンテキストを開放するまでソケットが開放されなくなります。
 * プログラムを終了する際、ソケットを閉じてから`zmq_ctx_destroy()`を呼んで下さい。これはコンテキストを破棄する関数です。

;This is at least the case for C development. In a language with automatic object destruction, sockets and contexts will be destroyed as you leave the scope. If you use exceptions you'll have to do the clean-up in something like a "final" block, the same as for any resource.

最後のケースはC言語で開発する場合です。
多くの言語では、スコープが外れた時にソケットやコンテキストなどのオブジェクトは自動的に開放されます。
もし例外を利用する場合は「final」ブロックでこれらのリソースを開放すると良いでしょう。

;If you're doing multithreaded work, it gets rather more complex than this. We'll get to multithreading in the next chapter, but because some of you will, despite warnings, try to run before you can safely walk, below is the quick and dirty guide to making a clean exit in a multithreaded ØMQ application.

マルチスレッドを利用している場合、これはもっと複雑になります。
マルチスレッドに関しては次の章で扱いますが、警告を無視して試してみたい人もいるでしょう。
以下は、マルチスレッドのØMQアプリケーションで正しく終了するための急しのぎのガイドです。

;First, do not try to use the same socket from multiple threads. Please don't explain why you think this would be excellent fun, just please don't do it. Next, you need to shut down each socket that has ongoing requests. The proper way is to set a low LINGER value (1 second), and then close the socket. If your language binding doesn't do this for you automatically when you destroy a context, I'd suggest sending a patch.

まず、複数のスレッドから同一のソケットを扱わないで下さい。
冗談ではありません、やらないで下さい。
次に、リクエスト中のソケットを接続を切る時はLINGERに小さい値(1秒程度)を設定し、それから接続を閉じて下さい。
もしあなたの利用している言語バインディングがこれを行わない場合、修正してパッチを送ることを推奨します。

;Finally, destroy the context. This will cause any blocking receives or polls or sends in attached threads (i.e., which share the same context) to return with an error. Catch that error, and then set linger on, and close sockets in that thread, and exit. Do not destroy the same context twice. The zmq_ctx_destroy in the main thread will block until all sockets it knows about are safely closed.

最後に、コンテキストを開放します。
これを行うと、コンテキストを共有して送受信を行っている別のスレッドでエラーが返ります。
エラーを拾い、`LINGER`を設定してソケットをクローズして下さい。
同じコンテキストを２回開放しないで下さい。
`zmq_ctx_destroy()`は全てのソケットが安全に閉じられるまでメインスレッドでブロックします。

;Voila! It's complex and painful enough that any language binding author worth his or her salt will do this automatically and make the socket closing dance unnecessary.

おしまい!これはとても複雑で痛みを伴いますが、有能な言語バインディングの作者が自動的にソケットを閉じてくれるので必ずしもこれを行う必要はないでしょう。

## なぜØMQが必要なのか
;Now that you've seen ØMQ in action, let's go back to the "why".

これまでØMQの動作について見てきましたが、前に戻って「何故」の話に戻りましょう。

;Many applications these days consist of components that stretch across some kind of network, either a LAN or the Internet. So many application developers end up doing some kind of messaging. Some developers use message queuing products, but most of the time they do it themselves, using TCP or UDP. These protocols are not hard to use, but there is a great difference between sending a few bytes from A to B, and doing messaging in any kind of reliable way.

今日多くのアプリケーションはLANやインターネットなどのネットワークを横断する機能を有しています。
そして多くのアプリケーション開発者は最終的メッセージング機能を必要とします。
開発者の中にはメッセージキュー製品を利用する人もいますが、ほとんどの人はTCPやUDPを利用して自前で実装します。
これらのプロトコルを利用するのは難しいことではありませんが、単にAからBへメッセージを送信する事と、信頼性のある方法でこれを行うのとでは大きな違いあがあります。

;Let's look at the typical problems we face when we start to connect pieces using raw TCP. Any reusable messaging layer would need to solve all or most of these:

それでは生のTCPを利用して部品を接続する際に発生する典型的な問題を見て行きましょう。
利用可能なメッセージングレイヤを実装するにはこれらの問題を解決する必要があります。

;* How do we handle I/O? Does our application block, or do we handle I/O in the background? This is a key design decision. Blocking I/O creates architectures that do not scale well. But background I/O can be very hard to do right.
;* How do we handle dynamic components, i.e., pieces that go away temporarily? Do we formally split components into "clients" and "servers" and mandate that servers cannot disappear? What then if we want to connect servers to servers? Do we try to reconnect every few seconds?
;* How do we represent a message on the wire? How do we frame data so it's easy to write and read, safe from buffer overflows, efficient for small messages, yet adequate for the very largest videos of dancing cats wearing party hats?
;* How do we handle messages that we can't deliver immediately? Particularly, if we're waiting for a component to come back online? Do we discard messages, put them into a database, or into a memory queue?
;* Where do we store message queues? What happens if the component reading from a queue is very slow and causes our queues to build up? What's our strategy then?
;* How do we handle lost messages? Do we wait for fresh data, request a resend, or do we build some kind of reliability layer that ensures messages cannot be lost? What if that layer itself crashes?
;* What if we need to use a different network transport. Say, multicast instead of TCP unicast? Or IPv6? Do we need to rewrite the applications, or is the transport abstracted in some layer?
;* How do we route messages? Can we send the same message to multiple peers? Can we send replies back to an original requester?
;* How do we write an API for another language? Do we re-implement a wire-level protocol or do we repackage a library? If the former, how can we guarantee efficient and stable stacks? If the latter, how can we guarantee interoperability?
;* How do we represent data so that it can be read between different architectures? Do we enforce a particular encoding for data types? How far is this the job of the messaging system rather than a higher layer?
;* How do we handle network errors? Do we wait and retry, ignore them silently, or abort?

 * I/O処理をどの様に行うか。ブロッキングI/Oか非同期I/Oのどっちにする?これは重要な仕様判断です。ブロッキングI/Oを選択するとスケーラビリティの無いアーキテクチャになります。一方、非同期I/Oを正しく実装するのはとても難しいです。

 * 動的なコンポーネントをどの様に処理するか。例えば部品が一時的に停止した時どうしますか? 一般的にコンポーネントは「サーバー」と「クライアント」に別れていることが多いですが、サーバーが落ちてしまった時どうしますか? サーバーとサーバーが接続するような場合は? 数秒毎に再接続するようにしますか?

 * メッセージをネットワーク上でどの様に表現するか。どの様にしてデータフレームを簡単に読み書きしたり、バッファーオーバーフローが起きないようにしたり、小さいメッセージを効果的に転送したり、パーティ用帽子をかぶった猫が踊っている巨大な動画を見ますか?

 * 即座に配信できないメッセージをどの様に処理するか。例えばコンポーネントが一時的にオフラインである場合、メッセージを破棄しますか? データベースに入れておきますか? それともメモリーキューに入れておきますか?

 * メッセージキューを何処に格納するか。キューが増えてきて読み込みが遅くなった時はどうしますか? その時の戦略は?

 * 欠落したデータをどの様に処理するか。新しいデータを待ちますか? リクエストを再送しますか? 信頼性のあるレイヤでネットワークを構築すればメッセージは欠落しないって? そのレイヤ自体がクラッシュしたらどうするの?

 * 複数のネットワークに配送する場合はどうする? TCPユニキャストの代わりにマルチキャストとかIPv6を使う? アプリケーションを書きなおしますか? ネットワークレイヤを抽象化しますか?

 * どの様にメッセージをルーティングする? 同じメッセージを複数の相手に送れる? 元のリクエスト送信者に返信出来る?

 * どうやってAPIをいろんな言語で実装する? ネットワークレベルのプロトコルを再実装する? ライブラリを再パッケージする? 前者ならどうやって安定したスタックを保証しますか? 後者ならどうやって相互運用性を保証しますか?

 * 異なるアーキテクチャでどの様にデータを表現しますか? 特定のデータエンコーディングに統一しますか? 何処までがメッセージングシステムの仕事で何処からが上位アプリケーションレイヤの仕事でしょうか?

 * ネットワークエラーをどの様に処理しますか? リトライしますか? 静かに無視しますか? 処理を中断しますか?

;Take a typical open source project like Hadoop Zookeeper and read the C API code in src/c/src/zookeeper.c. When I read this code, in January 2013, it was 4,200 lines of mystery and in there is an undocumented, client/server network communication protocol. I see it's efficient because it uses poll instead of select. But really, Zookeeper should be using a generic messaging layer and an explicitly documented wire level protocol. It is incredibly wasteful for teams to be building this particular wheel over and over.

2013年1月頃、典型的オープンソースプロジェクトであるHadoop ZookeeperのC APIコード(src/c/src/zookeeper.c)を読んでみると、4,200行のコードは謎めいていて、クライアント/サーバーの通信プロトコルはドキュメント化されていませんでした。
それはselectではなく効率的なpollを利用している事が確認できました。
Zookeeperはもっと一般的なメッセージングレイヤを利用し、ドキュメント化されたネットワークプロトコルを使ったほうが良いでしょうが、それはチームにとって車輪の再発明を繰り返す事になりとてつもなく無駄です。

;But how to make a reusable messaging layer? Why, when so many projects need this technology, are people still doing it the hard way by driving TCP sockets in their code, and solving the problems in that long list over and over?

しかしどうやって再利用可能なメッセージングレイヤを作るのでしょうか?
多くのプロジェクトでこの技術が必要とされているにも関わらず、何故人々は未だにTCPソケットを直に触って先ほど挙げた問題を解決するために繰り返し苦労しているのでしょうか。

;It turns out that building reusable messaging systems is really difficult, which is why few FOSS projects ever tried, and why commercial messaging products are complex, expensive, inflexible, and brittle. In 2006, iMatix designed AMQP which started to give FOSS developers perhaps the first reusable recipe for a messaging system. AMQP works better than many other designs, but remains relatively complex, expensive, and brittle. It takes weeks to learn to use, and months to create stable architectures that don't crash when things get hairy.

再利用可能なメッセージングシステムを作るのが本当に難しいということは、これを行うFOSSプロジェクトが少ないことや、商用メッセージング製品が複雑、高価で柔軟性が無く、不安定であることからも分ります。
2006年にiMatix社はAMQPという再利用可能なメッセージングシステムを恐らく最初にFOSS開発者に提供しました。
AMQPはその他の設計より上手く動作していましたが[比較的複雑で高価で不安定](http://www.imatix.com/articles:whats-wrong-with-amqp)でした。
数週間掛けて使い方を学び、数ヶ月掛けて安定したアーキテクチャを作り上げた結果、恐ろしいクラッシュが発生しなくなりました。

![メッセージングのはじまり](images/fig7.eps)

;Most messaging projects, like AMQP, that try to solve this long list of problems in a reusable way do so by inventing a new concept, the "broker", that does addressing, routing, and queuing. This results in a client/server protocol or a set of APIs on top of some undocumented protocol that allows applications to speak to this broker. Brokers are an excellent thing in reducing the complexity of large networks. But adding broker-based messaging to a product like Zookeeper would make it worse, not better. It would mean adding an additional big box, and a new single point of failure. A broker rapidly becomes a bottleneck and a new risk to manage. If the software supports it, we can add a second, third, and fourth broker and make some failover scheme. People do this. It creates more moving pieces, more complexity, and more things to break.

多くのメッセージングプロジェクトと同様に、AMQPも先ほど挙げた問題をアドレッシング、ルーティング、キューングを行う「ブローカー」という新しい概念を用いて解決しようとしました。
その結果、アプリケーションはブローカーに対して、クライアント/サーバープロトコルや、APIを利用してドキュメント化されていないプロトコルをやり取りするようになりました。
ブローカーは巨大で複雑なネットワークを縮小させる事に役立ちましたが、ブローカーをベースとしたメッセージングはZookeeperの様な製品では必ずしも良い結果が得られませんでした。
高性能なサーバーを追加していく内に、ブローカーが単一故障点になってしまったのです。
あっという間にブローカーはボトルネックとなり、管理上のリスクとなりました。
これをソフトウェアで解決する場合、第2、第3、第4のブローカーを追加し、フェイルオーバーの仕組みを作る必要がありました。人々がこれを行った結果、より多くの部品が増え、複雑になり、いろいろなものが壊れました。

;And a broker-centric setup needs its own operations team. You literally need to watch the brokers day and night, and beat them with a stick when they start misbehaving. You need boxes, and you need backup boxes, and you need people to manage those boxes. It is only worth doing for large applications with many moving pieces, built by several teams of people over several years.

そして中央ブローカーのセットアップには、専用の運用チームが必要でした。
そして、ブローカーを昼夜構わず監視し、素行の悪いヤツを見つけて棒で叩く必要がありました。
新しいサーバーが必要になり、さらにそのバックアップサーバーが必要になり、そのサーバーを管理する人材が必要になりました。この様な状況は、幾つものチームで数年に渡って運用する大規模なアプリケーションにおいては価値があるでしょう。

![Messaging as it Becomes](images/fig8.eps)

;So small to medium application developers are trapped. Either they avoid network programming and make monolithic applications that do not scale. Or they jump into network programming and make brittle, complex applications that are hard to maintain. Or they bet on a messaging product, and end up with scalable applications that depend on expensive, easily broken technology. There has been no really good choice, which is maybe why messaging is largely stuck in the last century and stirs strong emotions: negative ones for users, gleeful joy for those selling support and licenses.

つまり、中小規模のアプリケーション開発者にとってこれは罠なのです。
ネットワークプログラミングを避けて一枚岩なアプリケーションを作るか、
ネットワークプログラミングに挑戦して不安定で複雑なアプリケーションを作り、メンテナンスに苦しむか、
メッセージング製品に頼り、スケーラブルだけど高価で壊れやすい技術を利用するという選択肢があります。
前世紀のメッセージングが何故巨大であったかを考えると、これらは本当に良い選択肢ではありません。
サポートやライセンス販売する人は大喜びでしょうが、ユーザーにとって良い事は一つもないからです。

;What we need is something that does the job of messaging, but does it in such a simple and cheap way that it can work in any application, with close to zero cost. It should be a library which you just link, without any other dependencies. No additional moving pieces, so no additional risk. It should run on any OS and work with any programming language.

私達に必要なのはシンプルかつ安価で様々なアプリケーションで動作するメッセージングを機能です。
それは何にも依存せずリンクできるライブラリでなければなりません。
追加の部品は必要ありません、すなわち追加のリスクはありません。
それは、あらゆるOSとあらゆるプログラミング言語で動作しなければなりません。

;And this is ØMQ: an efficient, embeddable library that solves most of the problems an application needs to become nicely elastic across a network, without much cost.

そうして出来たのがØMQです。
ØMQはアプリケーションがネットワークを縦横無尽に横断する為に必要な問題を解決する、低コストで効率的な組み込みライブラリです。

;Specifically:

仕様:

;* It handles I/O asynchronously, in background threads. These communicate with application threads using lock-free data structures, so concurrent ØMQ applications need no locks, semaphores, or other wait states.
;* Components can come and go dynamically and ØMQ will automatically reconnect. This means you can start components in any order. You can create "service-oriented architectures" (SOAs) where services can join and leave the network at any time.
;* It queues messages automatically when needed. It does this intelligently, pushing messages as close as possible to the receiver before queuing them.
;* It has ways of dealing with over-full queues (called "high water mark"). When a queue is full, ØMQ automatically blocks senders, or throws away messages, depending on the kind of messaging you are doing (the so-called "pattern").
;* It lets your applications talk to each other over arbitrary transports: TCP, multicast, in-process, inter-process. You don't need to change your code to use a different transport.
;* It handles slow/blocked readers safely, using different strategies that depend on the messaging pattern.
;* It lets you route messages using a variety of patterns such as request-reply and pub-sub. These patterns are how you create the topology, the structure of your network.
;* It lets you create proxies to queue, forward, or capture messages with a single call. Proxies can reduce the interconnection complexity of a network.
;* It delivers whole messages exactly as they were sent, using a simple framing on the wire. If you write a 10k message, you will receive a 10k message.
;* It does not impose any format on messages. They are blobs from zero to gigabytes large. When you want to represent data you choose some other product on top, such as msgpack, Google's protocol buffers, and others.
;* It handles network errors intelligently, by retrying automatically in cases where it makes sense.
;* It reduces your carbon footprint. Doing more with less CPU means your boxes use less power, and you can keep your old boxes in use for longer. Al Gore would love ØMQ.

 * I/Oはバックグラウンドのスレッドで非同期に処理します。アプリケーションスレッドはロックフリーなデータ構造を利用して通信を行うので、ØMQアプリケーションはロックやセマフォなどの同期処理を必要としません。

 * コンポーネントを動的にできるように、ØMQは自動的に再接続を行います。これにより、どの様な順番でコンポーネントを実行してもよくなります。そしていつでもネットワークに参加して離脱出来る、サービス指向アーキテクチャを作ることが出来ます。

 * メッセージは必要に応じてキューに入れられます。それは賢く、メッセージは受信者に出来るだけ近いキューに入れられます。

 * HWM(満杯マーク)と呼ばれる方法でキューが溢れないようにします。キューが一杯になった時、ØMQは自動的に送信側をブロックするか、あるいはメッセージを捨てるかどうかをメッセージの種類によってコントロールできます。(これを「パターン」と呼びます。)

 * アプリケーションは様々な通信手段を利用する事が出来ます。例えば、TCP, マルチキャスト、プロセス間通信、プロセス内通信など。異なる通信手段を利用するためにコードを修正する必要はありません。

 * 受信側の読み込みが遅かったりブロックされている場合でも、メッセージパターンによって異なる戦略を利用して安全に処理します。

 * リクエスト-応答パターンや、pub-subパターンなど、様々なパターンを利用してメッセージをルーティング出来ます。これらのパターンによりネットワーク構造のトポロジーを構成できます。

 * キューのプロキシを構成したり、メッセージを採取したり転送したり出来ます。プロキシは相互接続によるネットワークの複雑性を緩和します。

 * 配送されたメッセージはフレーム境界を維持してそのまま送信されます。10Kバイトのメッセージを書き込んだ場合、受信側では10Kバイトのメッセージを受け取ります。

 * メッセージのフォーマットについては関わりません。データサイズはゼロかもしれませんし、何ギガバイトもの巨大サイズかもしれません。データの表現方法についてはmsgpackやGoogleのprotocol buffersなどの好きなライブラリを選んで使って下さい。

 * ネットワークエラーを賢く処理します。それが理にかなっている時は再試行を行います。

 * 二酸化炭素排出量を削減します。サーバーのCPU利用量と利用電力を減らします。そして古いサーバーを長く使い続けることが出来ます。アル・ゴアはØMQを気に入るでしょう。

;Actually ØMQ does rather more than this. It has a subversive effect on how you develop network-capable applications. Superficially, it's a socket-inspired API on which you do zmq_recv() and zmq_send(). But message processing rapidly becomes the central loop, and your application soon breaks down into a set of message processing tasks. It is elegant and natural. And it scales: each of these tasks maps to a node, and the nodes talk to each other across arbitrary transports. Two nodes in one process (node is a thread), two nodes on one box (node is a process), or two nodes on one network (node is a box)—it's all the same, with no application code changes.

実際のところØMQはこれらの事よりもっと多くのことを行います。
それはネットワーク機能を持ったアプリケーションの開発に多大な影響を及ぼします。
一見、zmq_recv()やzmq_send()はソケットAPIと同じように見えますが、メッセージ処理タスクは即座に中央ループに入り、複数のタスクに分解されます。
これは上品で自然な動作です。
そしてこれらのタスクはノードに対応付けされ、任意の通信経路を経由してノードに転送されます。
1プロセスに2ノード配置する時、ノードとはスレッドを意味します。
1つのサーバーに2ノード配置する時、ノードはプロセスの事です。
1つのネットワークに2ノード配置する場合、ノードはサーバーを意味します。
これらは全て同じように、アプリケーションを変更せず構成する事ができます。

## ソケットスケーラビリティ
;Let's see ØMQ's scalability in action. Here is a shell script that starts the weather server and then a bunch of clients in parallel:

ØMQのスケーラビリティを見てみましょう。
これは天気配信サーバーを起動し、クライアントを並列に実行するシェルスクリプトです。

~~~
wuserver &
wuclient 12345 &
wuclient 23456 &
wuclient 34567 &
wuclient 45678 &
wuclient 56789 &
~~~

;As the clients run, we take a look at the active processes using the top command', and we see something like (on a 4-core box):

4コアのマシンでクライアントの実行中に、topコマンドを利用すると以下のようなプロセス情報を確認できるでしょう。

~~~
PID  USER  PR  NI  VIRT  RES  SHR S %CPU %MEM   TIME+  COMMAND
7136  ph   20   0 1040m 959m 1156 R  157 12.0 16:25.47 wuserver
7966  ph   20   0 98608 1804 1372 S   33  0.0  0:03.94 wuclient
7963  ph   20   0 33116 1748 1372 S   14  0.0  0:00.76 wuclient
7965  ph   20   0 33116 1784 1372 S    6  0.0  0:00.47 wuclient
7964  ph   20   0 33116 1788 1372 S    5  0.0  0:00.25 wuclient
7967  ph   20   0 33072 1740 1372 S    5  0.0  0:00.35 wuclient
~~~

;Let's think for a second about what is happening here. The weather server has a single socket, and yet here we have it sending data to five clients in parallel. We could have thousands of concurrent clients. The server application doesn't see them, doesn't talk to them directly. So the ØMQ socket is acting like a little server, silently accepting client requests and shoving data out to them as fast as the network can handle it. And it's a multithreaded server, squeezing more juice out of your CPU.

ここで何が起こっているのか少し考えてみましょう。
天気情報サーバーは1つのソケットを持ち、5つのクライアントにデータを並行に送信しています。
私達は並行クライアントを数千ほどに増やすことが出来ます。
サーバーアプリケーションにこれらのコードは直接記述されていません。
クライアントのリクエストを静かに受け付け、出来るだけ素早くネットワークにデータを配信する小さなサーバとして機能振る舞います。
そしてそれはマルチスレッドサーバーであり、CPUリソースを無駄なく絞りとります。

## ØMQ v2.2 から ØMQ v3.2 へのアップグレード
### 互換性のある変更
;These changes don't impact existing application code directly:

これらの変更は既存のアプリケーションコードに直接影響はありません。

;* Pub-sub filtering is now done at the publisher side instead of subscriber side. This improves performance significantly in many pub-sub use cases. You can mix v3.2 and v2.1/v2.2 publishers and subscribers safely.
;* ØMQ v3.2 has many new API methods (zmq_disconnect(), zmq_unbind(), zmq_monitor(), zmq_ctx_set(), etc.)

 * PUB-SUBフィルタリングをサブスクライバ側だけでなくパブリッシャーサイドでも行えるようになりました。これは多くのpub-subユースケースでパフォーマンスを大きく改善します。v3.2とv2.1/v2.2を組み合わせても安全です。

 * ØMQ v3.2 で多くの新しいAPIが追加されました。(`zmq_disconnect()`, `zmq_unbind()`, `zmq_monitor()`, `zmq_ctx_set()`, など)

### 互換性の無い変更
;These are the main areas of impact on applications and language bindings:

アプリケーションや言語バインディングが影響を受ける主な変更です。

;* Changed send/recv methods: zmq_send() and zmq_recv() have a different, simpler interface, and the old functionality is now provided by zmq_msg_send() and zmq_msg_recv(). Symptom: compile errors. Solution: fix up your code.
;* These two methods return positive values on success, and -1 on error. In v2.x they always returned zero on success. Symptom: apparent errors when things actually work fine. Solution: test strictly for return code = -1, not non-zero.
;* zmq_poll() now waits for milliseconds, not microseconds. Symptom: application stops responding (in fact responds 1000 times slower). Solution: use the ZMQ_POLL_MSEC macro defined below, in all zmq_poll calls.
;* ZMQ_NOBLOCK is now called ZMQ_DONTWAIT. Symptom: compile failures on the ZMQ_NOBLOCK macro.
;* The ZMQ_HWM socket option is now broken into ZMQ_SNDHWM and ZMQ_RCVHWM. Symptom: compile failures on the ZMQ_HWM macro.
;* Most but not all zmq_getsockopt() options are now integer values. Symptom: runtime error returns on zmq_setsockopt and zmq_getsockopt.
;* The ZMQ_SWAP option has been removed. Symptom: compile failures on ZMQ_SWAP. Solution: redesign any code that uses this functionality.

 * `zmq_send()`と`zmq_recv()`メソッドのインターフェースが変更されました。古い関数は現在`zmq_msg_send()`と`zmq_msg_recv()`という名前で提供されています。症状: コンパイルエラーが発生します。解決方法: コードを修正する必要があります。

 * これらの2つのメソッドは、成功すると正の値、エラーが発生すると-1を返します。バージョン2では成功時は常に0を返していました。症状: 正常な動作なのにエラーが発生したように見えてしまう。解決方法: エラー処理を厳密に -1 と非ゼロで判定すること。

 * `zmq_poll()`はミリ秒ではなく、マイクロ秒待つようになりました。症状: アプリケーションの応答が止まって見える(正確には1000倍遅くなる)。解決方法: `zmq_poll()`を呼び出す時に、新しく定義された`ZMQ_POLL_MSEC`マクロを利用して下さい。

 * `ZMQ_NOBLOCK`マクロは`ZMQ_DONTWAIT`という名前に変更になりました。症状: コンパイルエラー

 * ZMQ_HWMソケットオプションは、ZMQ_SNDHWMとZMQ_RCVHWMに分割されました。症状: コンパイルエラー

 * 全てではありませんが、ほとんどの`zmq_getsockopt()`オプションの値は整数値です。症状: `zmq_setsockopt()`や`zmq_getsockopt()`の実行時にエラーが発生します。

 * `ZMQ_SWAP`オプションは廃止されました。症状: コンパイルエラー。解決方法: この機能を利用したコードを再設計して下さい。

### 互換性維持マクロ
;For applications that want to run on both v2.x and v3.2, such as language bindings, our advice is to emulate c3.2 as far as possible. Here are C macro definitions that help your C/C++ code to work across both versions (taken from CZMQ):

アプリケーションをv2.xとv3.2の両方で動作させたい場合があります。
以下のCマクロ定義は、両方のバージョンで動作させる為に役立ちます。

~~~
#ifndef ZMQ_DONTWAIT
# define ZMQ_DONTWAIT ZMQ_NOBLOCK
#endif
#if ZMQ_VERSION_MAJOR == 2
#   define zmq_msg_send(msg,sock,opt) zmq_send (sock, msg, opt)
#   define zmq_msg_recv(msg,sock,opt) zmq_recv (sock, msg, opt)
#   define zmq_ctx_destroy(context) zmq_term(context)
#   define ZMQ_POLL_MSEC 1000 // zmq_poll is usec
#   define ZMQ_SNDHWM ZMQ_HWM
#   define ZMQ_RCVHWM ZMQ_HWM
#elif ZMQ_VERSION_MAJOR == 3
#   define ZMQ_POLL_MSEC 1 // zmq_poll is msec
#endif
~~~

## 警告: 不安定なパラダイム!
;Traditional network programming is built on the general assumption that one socket talks to one connection, one peer. There are multicast protocols, but these are exotic. When we assume "one socket = one connection", we scale our architectures in certain ways. We create threads of logic where each thread work with one socket, one peer. We place intelligence and state in these threads.

従来のネットワークプログラミングは一般的に1ソケットに対して1つの接続、1ピアと会話することを前提にして構築されています。
マルチキャストプロトコルがありますが、これらはちょっと風変わりです。
私達は「1ソケット = 1コネクション」を前提としたアーキテクチャを有る意味で拡張しました。
論理的なスレッドを作成しそれぞれのスレッドが1ソケット、1ピアとして機能します。
これらのスレッドに情報や状態を格納します。

;In the ØMQ universe, sockets are doorways to fast little background communications engines that manage a whole set of connections automagically for you. You can't see, work with, open, close, or attach state to these connections. Whether you use blocking send or receive, or poll, all you can talk to is the socket, not the connections it manages for you. The connections are private and invisible, and this is the key to ØMQ's scalability.

ØMQの世界では、全てのコネクションの集合を自動的に管理する早くて小さい通信エンジンへの出入口です。
あなたはオープンやクローズ、コネクションに設定された状態の設定を見ることが出来ません。
送受信をブロッキングで行うかポーリングするかどうかはあなたがソケットと会話して決定します。コネクションはこれを自動的に管理しません。
コネクションは隠蔽化しているため直接見えませんが、これがØMQのスケーラビリティの重要な鍵になります。

;This is because your code, talking to a socket, can then handle any number of connections across whatever network protocols are around, without change. A messaging pattern sitting in ØMQ scales more cheaply than a messaging pattern sitting in your application code.

なぜならソケットと会話することで、ネットワークプロトコルやコネクション数を操作することが出来るからです。
メッセージングパターンはあなたのアプリケーションコードで実装するよりも、ØMQのレイヤで実装したほうがより拡張性が高まります。

;So the general assumption no longer applies. As you read the code examples, your brain will try to map them to what you know. You will read "socket" and think "ah, that represents a connection to another node". That is wrong. You will read "thread" and your brain will again think, "ah, a thread represents a connection to another node", and again your brain will be wrong.

ですので一般的な仮定が通用しない場合があります。
サンプルコードを読む時に、あなたの頭の中で、既存の知識とマッピングしようとするかもしれません。
「ソケット」という言葉を見た時、「ああ、これは別のノードへのコネクションを表すのね」と思うでしょうが誤りです。
「スレッド」という言葉を見た時、「ああ、スレッドが別ノードへのコネクションを制御しているのね」と思うかもしれませんが、これもまた誤りです。

;If you're reading this Guide for the first time, realize that until you actually write ØMQ code for a day or two (and maybe three or four days), you may feel confused, especially by how simple ØMQ makes things for you, and you may try to impose that general assumption on ØMQ, and it won't work. And then you will experience your moment of enlightenment and trust, that zap-pow-kaboom satori paradigm-shift moment when it all becomes clear.

このガイドブックを初めて読んでいるのなら、実際にØMQのコードを書けるようになるまで1,2日(もしくは3,4日)かかるでしょう。
特に、ØMQがどの様に物事を単純化しているかについてあなたは混乱するかもしれません。あるいはØMQで一般的な仮定を適用しようとして上手く行かないかもしれません。
そして全てが明らかになったその時、あなたはzap-pow-kaboomパラダイムシフトの真理と悟りの瞬間を経験するでしょう。

