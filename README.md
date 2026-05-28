# go-lambda-with-terraform

terraformの実行のみでGoで書かれたLambdaファンクションを作成する。
以下を満たすよう実装している。
- ビルドしたバイナリファイルやzipのデプロイパッケージをGit管理外にする
- ソースコードが変更された時以外はビルドしない

なお、ディレクトリのハッシュ値を計算するアイデアは[こちら](https://zenn.dev/skanehira/articles/2024-06-30-tf-detect-file-diff)を参考にさせていただいた。

## AWS SAMを利用したローカルでの実行

1. 実行環境を用意する。

    `--hook-name`は`terraform`が必須で、Lambdaファンクションを特定したい場合は空白の後に`<リソースタイプ>.<リソース名>`で指定できる。(e.g: `aws_lambda_function.this`)

    ```bash
    sam build --hook-name terraform
    ```

1. 実行する。

    dockerデーモンのsocketファイルが`/var/run/docker.sock`以外の場合は、`DOCKER_HOST`に`unix:///path/to/socket.sock`形式で指定する。
    こちらもLambdaファンクションを特定したい場合は空白の後に`<リソースタイプ>.<リソース名>`で指定できる。

    ```bash
    sam local invoke --hook-name terraform aws_lambda_function.this
    ```
