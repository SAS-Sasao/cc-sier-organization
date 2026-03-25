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
