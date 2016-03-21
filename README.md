# NatEditor

RV-S340NE（NTTのひかり電話対応VDSLルータ）の静的IPマスカレード設定（以下、NAT設定）をCLIから行うためのツール

自宅サーバ向けにNAT設定を変更する際のルータのレスポンスが悪いため、コマンド操作で設定できるようにしました

現状はCLIでの操作のみですがAPIとして利用できるよう改良予定です

## 前提条件

- RV-S340NEと同一LAN内のホストでツールを起動する必要があります
- Selenium Webdriverを利用しているため依存ライブラリのインストールが必要です（[セットアップ](#セットアップ)参照）
- 動作はRV-S340NEの2016年3月21日時点での最新ファームウェアVersion 19.41で確認しています

## セットアップ

Selenium Webdriverを利用するため以下の初期設定が必要です

他にも不足しているライブラリ等があるかもしれませんので、エラーメッセージ等から適宜必要なライブラリをインストールしてください

### Ubuntu

```
 $ sudo apt-get install ruby build-essential firefox xvfb
 $ sudo gem install bundler --no-ri --no-rdoc
 $ bundle install --path vendor/bundle
```

### Fedora

```
 $ sudo dnf groupinstall -y "RPM Development Tools"
 $ sudo dnf groupinstall -y "C Development Tools and Libraries"
 $ sudo dnf install -y ruby ruby-devel gem firefox libXtst-devel xorg-x11-server-Xvfb
 $ sudo gem install bundler --no-ri --no-rdoc
 $ bundle install --path vendor/bundle
```

### OS X

```
 $ brew cask install xquartz  # XQuartz導入済みであれば不要
 $ brew cask install firefox  # Firefox導入済みであれば不要
 $ export GEM_HOME=~/.gem
 $ gem install bundler
 $ bundle install --path vendor/bundle
```
PATHに `/usr/X11/bin` を追加する

### Raspberry Pi

```
 $ sudo apt-get install ruby ruby-dev build-essential iceweasel xvfb
 $ sudo gem install bundler --no-ri --no-rdoc
 $ bundle install --path vendor/bundle
```

## 使い方

### 起動

```
 $ bundle exec ruby nateditor.rb
```

### NAT設定変更作業

設定変更の流れは以下のようなイメージです

```
$ bundle exec ruby nateditor.rb headless
type 'help' to help. type 'exit' to terminate.

NatEditor> login
IP Address of RS-S340NE (192.168.1.1): 192.168.11.1
Password:
Please wait...
NatEditor> print
num avail  prot port   host             num avail  prot port   host
 1  true   TCP  1111   192.168.1.111    26  -
 2  true   TCP  2222   192.168.1.122    27  -
 3  true   TCP  3333   192.168.1.133    28  -
 4  true   UDP  700    192.168.1.70     29  -
 5  true   UDP  800    192.168.1.80     30  -
 6  true   UDP  900    192.168.1.90     31  -
 7  -                                   32  -
 8  -                                   33  true   TCP  30000  192.168.1.3
 9  -                                   34  false  TCP  31000  192.168.1.4
10  -                                   35  false  TCP  32000  192.168.1.5
11  -                                   36  true   TCP  40000  192.168.1.3
12  -                                   37  true   TCP  41000  192.168.1.4
13  -                                   38  true   TCP  42000  192.168.1.5
14  -                                   39  -
15  -                                   40  -
16  -                                   41  -
17  true   TCP  80     192.168.1.5      42  -
18  true   TCP  12345  192.168.1.5      43  -
19  true   TCP  23456  192.168.1.5      44  -
20  true   TCP  34567  192.168.1.5      45  -
21  -                                   46  -
22  -                                   47  -
23  -                                   48  -
24  -                                   49  -
25  -                                   50  -

NatEditor> get 17
num avail  prot port   host
17  true   TCP  80     192.168.1.5

NatEditor> set 17 true tcp 80 192.168.1.4
Set 17
num avail  prot port   host
10  true   TCP  80     192.168.1.5
->
10  true   TCP  80     192.168.1.4
Are you sure? [yN] y
Success
```

## コマンド解説

__help__

ヘルプメッセージを表示

__login__

RV-S340NEにログイン

IPアドレス（省略時はデフォルトの192.168.1.1に接続します）とパスワードを入力

ユーザ名はuserで固定のため入力不要

__exit__

ツールを終了

__print__

NAT設定を一覧表示

__get (番号)__

NAT設定を表示

RV-S340NEではNAT設定に1〜50までの項番が振られており、本ツールではこの番号を指定してNAT設定を操作します

```
> get 10
num avail  prot port   host
10  true   TCP  8080   192.168.1.100
```

__set (番号)__

NAT設定を変更

```
> set 10 true tcp 5000 192.168.1.100
Set 10
num avail  prot port   host
10  true   TCP  8080   192.168.1.100
->
10  true   TCP  5000   192.168.1.100
Are you sure? [yN] y
```

__toggle (番号)__

NAT設定の状態（有効or無効）を反転

```
> toggle 10
Toggle 10 true -> false
Are you sure? [yN] y
```

__del (番号)__

NAT設定を削除

```
> del 10
Delete 10
Are you sure? [yN] y
```

__reload__

NAT設定をすべて再読み込み

ツール使用中に並行してブラウザからNAT設定を操作した場合等、ブラウザから設定値を再読み込みしたい場合に利用

## 参考

対話型コンソールの仕組みにはPryを使っています。以下の記事を参考にさせて頂きました

[対話型のコンソールアプリをpryの上に構築したらだいぶ楽できた](http://sho.tdiary.net/20131128.html#p01)
