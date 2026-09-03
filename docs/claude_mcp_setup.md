# Claude Code 向け MCP サーバーセットアップスクリプト解説

このドキュメントでは、ros-mcp-server を Claude Code の MCP サーバーとして登録・起動するための2つのシェルスクリプトを解説します。

---

## setup_claude_mcp.sh

### 概要

ros-mcp-server を Claude Code の MCP サーバーとして自動設定するセットアップスクリプトです。初回セットアップ時に一度実行するだけで、依存関係のインストールから Claude Code の設定ファイル更新まで一括で行います。

### 使い方

```bash
bash setup_claude_mcp.sh [ROS_DISTRO] [ROS_DOMAIN_ID]
```

| 引数 | デフォルト値 | 説明 |
|------|-------------|------|
| `ROS_DISTRO` | `jazzy` | 使用する ROS 2 ディストリビューション名 |
| `ROS_DOMAIN_ID` | `0` | ROS 2 のドメイン ID |

**実行例：**

```bash
# デフォルト（jazzy、ドメイン ID 0）
bash setup_claude_mcp.sh

# ROS Humble、ドメイン ID 7 で使う場合
bash setup_claude_mcp.sh humble 7
```

### 処理ステップ

スクリプトは以下の5ステップを順に実行します。

#### ステップ 1 — 前提条件の確認

- 指定した ROS ディストリビューションが `/opt/ros/<DISTRO>/setup.bash` に存在するか確認します。見つからない場合はエラー終了します。
- Python パッケージマネージャー `uv` が `~/.local/bin/uv` に存在するか確認します。存在しない場合は自動インストールします。

#### ステップ 2 — Python 依存パッケージのインストール

`uv sync` を実行して `pyproject.toml` に定義された依存パッケージをインストールします。

#### ステップ 3 — start_server.sh の生成

ROS 環境と `ROS_DOMAIN_ID` を組み込んだ起動ラッパースクリプト `start_server.sh` をスクリプトと同じディレクトリに生成します（詳細は後述）。

#### ステップ 4 — グローバル MCP 設定の更新（`~/.claude/settings.json`）

Claude Code のグローバル設定ファイルに `ros-mcp-server` エントリを追記します。登録内容は以下のとおりです。

```json
"mcpServers": {
  "ros-mcp-server": {
    "name": "ROS MCP Server",
    "transport": "stdio",
    "command": "/bin/bash",
    "args": ["<スクリプトのディレクトリ>/start_server.sh"]
  }
}
```

設定ファイルが存在しない場合は `{}` から新規作成します。

#### ステップ 5 — プロジェクト設定の修正（`~/.claude.json`）

`~/.claude.json` 内のプロジェクト設定に既存の ROS 関連エントリがある場合、その設定を `start_server.sh` を使う新しい設定に置き換えます。ROS 関連エントリが存在しない場合は `ros-mcp` キーで新規追加します。`~/.claude.json` 自体が存在しない場合はスキップします。

### 実行後の作業

セットアップ完了後、**Claude Code を再起動**することで ros-mcp-server に接続されます。

---

## start_server.sh

### 概要

`setup_claude_mcp.sh` によって自動生成される起動ラッパースクリプトです。Claude Code が MCP サーバーを起動する際に呼び出します。手動で編集・実行することも可能です。

### 生成される内容

```bash
#!/bin/bash
source /opt/ros/<ROS_DISTRO>/setup.bash
export ROS_DOMAIN_ID=<ROS_DOMAIN_ID>
cd <スクリプトのディレクトリ>
exec <uv のパス> run server.py
```

### 各行の役割

| 行 | 説明 |
|----|------|
| `source /opt/ros/.../setup.bash` | ROS 2 環境変数（パス・ライブラリ等）を現在のシェルに読み込みます |
| `export ROS_DOMAIN_ID=...` | ROS 2 ノードが通信するドメインを指定します（異なる ROS ネットワークを分離するために使用） |
| `cd <ディレクトリ>` | `server.py` の相対パス解決のため、スクリプトのディレクトリに移動します |
| `exec uv run server.py` | `uv` を使って `server.py` を起動します。`exec` により現在のシェルプロセスをサーバープロセスで置き換えます |

### 注意事項

- このファイルはマシン固有のパスを含む**生成ファイル**です。設定を変更したい場合は `setup_claude_mcp.sh` を再実行してください。
- `ROS_DOMAIN_ID` を変更する場合も `setup_claude_mcp.sh` を引数付きで再実行するのが確実です。

---

## セットアップ全体のフロー

```
setup_claude_mcp.sh 実行
        │
        ├─ [1] ROS / uv の確認
        ├─ [2] uv sync（依存パッケージ）
        ├─ [3] start_server.sh を生成
        ├─ [4] ~/.claude/settings.json を更新
        └─ [5] ~/.claude.json を更新
                │
                └─ Claude Code を再起動
                        │
                        └─ Claude Code が start_server.sh を呼び出し
                                │
                                └─ ROS 環境を読み込んで server.py を起動
```
