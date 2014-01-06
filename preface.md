# まえがき {-}
## ØMQとは {-}
ØMQ(ZeroMQ, 0MQ, zmq などとも呼ばれます)は組み込みネットワークライブラリの様にも見ることもできますが、並行フレームワークの様に機能します。
それはプロセス内通信、プロセス間通信、TCPやマルチキャストの様な幅広い通信手段を用いてアトミックにメッセージを転送する通信ソケットを提供します。
ソケットをファンアウト、Pub-Sub、タスク分散、リクエスト・応答の様なパターンでN対Nで接続できます。
非同期I/Oモデルによりアプリケーションはマルチコアスケーラブルな非同期メッセージ処理タスクとして構成されていますので、製品クラスタを構成する上で十分高速です。
ØMQは多くのプログラミング言語向けのAPIを持ち、ほとんどのOSで動作します。
ØMQは[iMatix](http://www.imatix.com/)で開発され、LGPLv3ライセンスで配布されています。

## 事の発端 {-}
我々は通常のTCPを手にしている。それにソビエトの秘密研究所から盗まれた放射性同位元素が注入され、1950年代の宇宙線が放射された。
それはひどい変装趣味の漫画作家に渡り、全身タイツをまとい、筋肉が盛り上がった。
ええ、こうしてØMQソケットはネットワーキングの世界を守るスーパーヒーローになったのです。

![恐ろしいアクシデント](images/fig1.eps)

## ゼロの哲学 {-}
ØMQのØはトレードオフが本質です。
まず、この奇妙な名前によってGoogleやTwitterの検索での可視性が低下しています。
一方で、デンマークのひどい奴らが「ØMG(笑)」とか「Øは変な形をしたゼロではない」とか「Rødgrød med Fløde!」(クリームがのったデンマークのおやつ)とか言ってくるのは明らかな侮辱であり、不愉快です。うん、どうやらこれはフェアなトレードだ。

元来、ØMQのゼロは「仲介無し」や(出来るだけ)「遅延ゼロ」(に近づける)という意味を持っていました。
以来それは「ゼロ管理」や「ゼロコスト」、「無駄がゼロ」といった別の目的を包含するようになりました。
一般的な言葉で言うと、最小主義の文化がプロジェクトに浸透している事を示しています。
私達は新たな機能を追加するというよりも、複雑さを取り除くことを重要視します。

## 対象読者 {-}
この本は、コンピューティングの未来を支配する大規模な分散ソフトウェアの作り方を学びたいプロのプログラマ向けに書かれています。
ØMQは多くのプログラミング言語で使えるにも関わらず、ほとんどのサンプルコードはC言語で書かれているため、あなたがC言語を読めることを想定しています。
あなたがスケーラビリティの問題を気にしていることを想定しています。
あなたが最小のコストで最良の結果を必要としている事を想定しています。そうしないとØMQのトレードオフについて認識できないからです。
それ以外のØMQを使う上で必要なネットワークや分散コンピューティングなどの基本的な概念は出来るだけ説明するように心がけます。

## 謝辞 {-}
このテキストを[オライリーの書籍](http://shop.oreilly.com/product/0636920026136.do)として出版する為に企画と編集を行なってくれたAndy Oramに感謝します。

以下の方々の貢献に感謝します:
Bill Desmarais, Brian Dorsey, Daniel Lin, Eric Desgranges, Gonzalo Diethelm, Guido Goldstein, Hunter Ford, Kamil Shakirov, Martin Sustrik, Mike Castleman, Naveen Chawla, Nicola Peduzzi, Oliver Smith, Olivier Chamoux, Peter Alexander, Pierre Rouleau, Randy Dryburgh, John Unwin, Alex Thomas, Mihail Minkov, Jeremy Avnet, Michael Compton, Kamil Kisiel, Mark Kharitonov, Guillaume Aubert, Ian Barber, Mike Sheridan, Faruk Akgul, Oleg Sidorov, Lev Givon, Allister MacLeod, Alexander D'Archangel, Andreas Hoelzlwimmer, Han Holl, Robert G. Jakabosky, Felipe Cruz, Marcus McCurdy, Mikhail Kulemin, Dr. Gergő Érdi, Pavel Zhukov, Alexander Else, Giovanni Ruggiero, Rick "Technoweenie", Daniel Lundin, Dave Hoover, Simon Jefford, Benjamin Peterson, Justin Case, Devon Weller, Richard Smith, Alexander Morland, Wadim Grasza, Michael Jakl, Uwe Dauernheim, Sebastian Nowicki, Simone Deponti, Aaron Raddon, Dan Colish, Markus Schirp, Benoit Larroque, Jonathan Palardy, Isaiah Peng, Arkadiusz Orzechowski, Umut Aydin, Matthew Horsfall, Jeremy W. Sherman, Eric Pugh, Tyler Sellon, John E. Vincent, Pavel Mitin, Min RK, Igor Wiedler, Olof Åkesson, Patrick Lucas, Heow Goodman, Senthil Palanisami, John Gallagher, Tomas Roos, Stephen McQuay, Erik Allik, Arnaud Cogoluègnes, Rob Gagnon, Dan Williams, Edward Smith, James Tucker, Kristian Kristensen, Vadim Shalts, Martin Trojer, Tom van Leeuwen, Hiten Pandya, Harm Aarts, Marc Harter, Iskren Ivov Chernev, Jay Han, Sonia Hamilton, Nathan Stocks, Naveen Palli, Zed Shaw

## 訳者より {-}
現在翻訳作業中です。誤字・誤訳等ありましたら[\@hamano](https://twitter.com/hamano)まで連絡下さい。
校正を手伝ってくれた亀井亜佐夫さんに感謝します。

