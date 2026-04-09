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

## aws-iac-mcp-server

- **サービス名**: AWS Infrastructure as Code MCP Server
- **提供元**: awslabs（AWS公式）
- **ステータス**: active
- **連携部署**: [dept-secretary, dept-research]
- **想定操作**: CloudFormationテンプレート検証、コンプライアンスチェック、デプロイトラブルシュート、CDK/CFnドキュメント検索、CDKベストプラクティス参照
- **設定先**: .mcp.json（プロジェクトルート）
- **認証**: AWSプロファイル（デプロイトラブルシュート機能使用時のみ。検証・検索は不要）
- **前提条件**: uv
- **トリガー**: IaCソース（CloudFormation / CDK）を書くとき、テンプレート検証時、デプロイ失敗時
- **提供ツール**:
  - `validate_cloudformation_template` — CFnテンプレートの構文・スキーマ検証（cfn-lint使用）
  - `check_cloudformation_template_compliance` — セキュリティ・コンプライアンス規則検証（cfn-guard使用）
  - `troubleshoot_cloudformation_deployment` — デプロイ失敗の分析と解決ガイダンス
  - `search_cloudformation_documentation` — CloudFormation公式ドキュメント検索
  - `search_cdk_documentation` — CDK API参照・実装パターン検索
  - `search_cdk_samples_and_constructs` — CDKサンプルコード・コンストラクト検索
  - `cdk_best_practices` — CDKベストプラクティスへのアクセス
  - `read_iac_documentation_page` — CDK/CFnドキュメントをMarkdown形式で取得
- **参考ドキュメント**:
  - [公式ページ](https://awslabs.github.io/mcp/servers/aws-iac-mcp-server)

## drawio

- **サービス名**: Draw.io MCP Server
- **提供元**: jgraph（draw.io公式）
- **ステータス**: active
- **連携部署**: [dept-secretary, dept-research]
- **想定操作**: ER図・フローチャート・シーケンス図・ネットワーク図・C4モデル等の汎用図の生成。Mermaid記法・CSV・draw.io XMLの3形式に対応
- **設定先**: .mcp.json（プロジェクトルート）
- **認証**: 不要
- **前提条件**: Node.js, npx
- **トリガー**: ER図、フローチャート、シーケンス図、ネットワーク図、業務フロー図、C4モデル、draw.io
- **提供ツール**:
  - `open_drawio_mermaid` — Mermaid記法から図を生成（フローチャート・シーケンス図・状態遷移図向け）
  - `open_drawio_csv` — CSVデータから図を生成（組織図・ネットワークトポロジ向け）
  - `open_drawio_xml` — draw.io XMLから図を生成（アーキテクチャ図・インフラ構成図向け、最も精密なレイアウト制御）
- **使い分けガイド**:
  - シンプルなフロー・シーケンス図 → `open_drawio_mermaid`
  - 階層構造・組織図 → `open_drawio_csv`
  - 精密なレイアウト・AWS以外のインフラ図 → `open_drawio_xml`
  - AWS構成図 → 引き続き `aws-diagram-mcp-server` を推奨（AWSアイコン対応）
- **出力形式**: draw.ioエディタで直接開けるURL。エディタからPNG/SVG/PDFにエクスポート可能
- **参考ドキュメント**:
  - [GitHub](https://github.com/jgraph/drawio-mcp)
  - [サーバーワークスBlog解説](https://blog.serverworks.co.jp/drawio-mcp-claude-code)
  - [Zenn解説記事](https://zenn.dev/aya1357/articles/12f4ede03bc32c)

## figma

- **サービス名**: Figma MCP Server
- **提供元**: Figma公式
- **ステータス**: active
- **連携部署**: [dept-secretary, dept-research]
- **想定操作**: Figmaデザイン取得・スクリーンショット・メタデータ取得、FigJamダイアグラム生成、Code Connect管理
- **設定先**: Claude Code組み込み（claude.ai MCP connector）
- **認証**: OAuth（ブラウザ認証、`/mcp` → Figma → Authenticate）
- **プラン**: Starter（Viewシート）— 読み取り系は制限なし、キャンバス書き込みは制限あり
- **提供ツール**:
  - `get_design_context` — デザインのコード・スクリーンショット・コンテキストヒントを取得
  - `get_screenshot` — デザインのスクリーンショット取得
  - `get_metadata` — ファイルメタデータ取得
  - `get_figjam` — FigJamファイルのリソース取得
  - `generate_diagram` — FigJamにダイアグラム生成
  - `get_variable_defs` — デザイン変数（トークン）定義の取得
  - `search_design_system` — デザインシステム検索
  - `use_figma` — キャンバスへの書き込み（Viewシートでは制限あり）
  - `create_new_file` — 新規Figmaファイル作成
  - `whoami` — 認証ユーザー情報の確認
  - `get_code_connect_map` — Code Connectマッピング取得
  - `get_code_connect_suggestions` — Code Connect候補の提案
  - `get_context_for_code_connect` — Code Connectコンテキスト取得
  - `add_code_connect_map` — Code Connectマッピング追加
  - `send_code_connect_mappings` — Code Connectマッピング送信
  - `create_design_system_rules` — デザインシステムルール作成
- **参考ドキュメント**:
  - [公式ドキュメント](https://developers.figma.com/docs/figma-mcp-server/)
  - [リモートサーバーインストール](https://developers.figma.com/docs/figma-mcp-server/remote-server-installation/)
  - [GitHub ガイド](https://github.com/figma/mcp-server-guide)
