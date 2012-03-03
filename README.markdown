# HttpTakStreaming

## 概要
rtmpのストリーミング動作は、安定した動作をするもののスケーリングすると一気に難度があがる上
<br />配信中に、おいそれとサーバーを停止させることができません。
<br />この問題に対処するために、adobeがhttpストリーミングを出していますが
<br />Video on demandは簡単に導入できるもののライブは対応できないので独自につくってみました。

## 動作の流れ
1. red5サーバーに普通に映像をpublishする。
2. publishデータを独自ファイル、fthとftmに分解して一定間隔ごとに保存していく。
3. ftpで各httpサーバーにfth、ftmサーバーを配布する。
4. プレーヤーからhttpでftfファイル(xml形式)を応答するphpにアクセスして、fth、ftmファイルの情報を手に入れる。
5. fthファイルをダウンロードして処理する。
6. ftmファイルをダウンロードして映像を流す。(これを繰り返す。)

## 使い方概要
1. htsディレクトリの内容をred5のwebappsにコピーしてアプリケーションをインストールする。
2. red5-web.xmlのproperty interval(各パケットの長さ(ミリ秒)) outputPath(出力位置) tmpPath(一時生成位置)を設定
3. ftfFile.phpのconfig部を書き換える。
4. flexのプロジェクトにflex、logger、playerの３つを導入してplayer.mxmlをコンパイルする。
細かい部分は割愛してます。

## ライセンス
ライセンスはGNU LESSER GENERAL PUBLIC LICENSE Version 3,29とします。
http://www.gnu.org/licenses/lgpl.html

## 現状の問題について
いまのところflex側のライブラリの作り込みが甘くパケットのダウンロードが遅れたりするみたいです。
<br />ここが今後の課題です。

## 拡張バージョンについて
基本バージョンは自由につかっていただけるように公開します。
<br />有償サポートとして以下を予定しています。

1. wowzaやfmsをベースにしたHttpTakStreamingの実装
2. ftpより高速なデータ配布、共有方式の実装
3. セキュアなデータ送信

## 作者へのコンタクト
twitter: @taktod https://twitter.com/#!/taktod
blog: プログラムしてみようか http://poepoemix.blogspot.com/
