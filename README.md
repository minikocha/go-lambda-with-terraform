# go-lambda-with-terraform

terraformの実行のみでGoで書かれたLambdaファンクションを作成する。
以下を満たすよう実装している。
- ビルドしたバイナリファイルやzipのデプロイパッケージをGit管理外にする
- ソースコードが変更された時以外はビルドしない

なお、ディレクトリのハッシュ値を計算するアイデアは[こちら](https://zenn.dev/skanehira/articles/2024-06-30-tf-detect-file-diff)を参考にさせていただいた。
