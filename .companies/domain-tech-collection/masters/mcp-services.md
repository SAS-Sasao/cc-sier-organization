# MCP サービス一覧

## aws-knowledge-mcp-server

- **サービス名**: AWS Knowledge MCP Server
- **提供元**: awslabs（AWS公式）
- **ステータス**: active
- **連携部署**: [dept-secretary, dept-research, dept-retail-domain]
- **想定操作**: AWSドキュメント検索、リージョン情報取得、サービス利用可否確認、エージェントSOP取得
- **設定先**: .mcp.json（プロジェクトルート）
- **認証**: 不要（公開リモートサーバー、レート制限あり）
- **提供ツール**:
  - `search_documentation` — AWSドキュメント・SOP横断検索
  - `read_documentation` — AWSドキュメントをMarkdownで取得
  - `recommend` — ドキュメントの関連コンテンツ推薦
  - `list_regions` — AWSリージョン一覧取得
  - `get_regional_availability` — サービス・機能のリージョン別利用可否確認
  - `retrieve_agent_sops` — エージェントSOP（手順書）取得

## aws-diagram-mcp-server

- **サービス名**: AWS Diagram MCP Server
- **提供元**: awslabs（AWS公式）
- **ステータス**: active
- **連携部署**: [dept-secretary, dept-research, dept-retail-domain]
- **想定操作**: AWSアーキテクチャ構成図の生成、シーケンス図・フローチャートの作成
- **設定先**: .mcp.json（プロジェクトルート）
- **認証**: 不要
- **前提条件**: uv, Python 3.10, GraphViz
- **提供ツール**:
  - `generate_diagram` — Python diagrams DSLを使用した構成図生成
  - `get_diagram_examples` — 図種別のサンプルコード取得
  - `list_icons` — 利用可能アイコンの一覧取得
- **参考ドキュメント**:
  - [公式README](https://github.com/awslabs/mcp/blob/main/src/aws-diagram-mcp-server/README.md)
  - [Qiita解説記事](https://qiita.com/y5347M/items/aa35cd9a073937066359)
