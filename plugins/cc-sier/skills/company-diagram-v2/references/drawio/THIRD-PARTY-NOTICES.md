<!-- This file documents third-party assets vendored into references/drawio/ -->

# Third-Party Notices — references/drawio/

## awslabs/agent-plugins (deploy-on-aws)

- **Source**: https://github.com/awslabs/agent-plugins/tree/main/plugins/deploy-on-aws
- **License**: Apache License 2.0
- **Copyright**: Amazon.com, Inc. or its affiliates. All Rights Reserved.
- **Upstream commit**: 7a17df718d26f07414b876e77a7480fa25089b08
- **Retrieval date**: 2026-06-13

### Vendored files

| File | Upstream path |
|---|---|
| `xml-rules.md` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/xml-rules.md` |
| `style-guide.md` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/style-guide.md` |
| `layout-guidelines.md` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/layout-guidelines.md` |
| `aws4-shapes-services.md` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/aws4-shapes-services.md` |
| `aws4-shapes-resources.md` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/aws4-shapes-resources.md` |
| `xml-templates-structure.md` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/xml-templates-structure.md` |
| `xml-templates-examples.md` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/xml-templates-examples.md` |
| `diagram-templates-basic.md` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/diagram-templates-basic.md` |
| `diagram-templates-advanced.md` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/diagram-templates-advanced.md` |
| `group-styles.md` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/group-styles.md` |
| `general-icons.md` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/general-icons.md` |
| `cli-export.md` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/cli-export.md` |
| `post-processing.md` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/post-processing.md` |
| `scripts/validate_drawio.py` | `plugins/deploy-on-aws/scripts/lib/validate_drawio.py` |
| `scripts/post_process_drawio.py` | `plugins/deploy-on-aws/scripts/lib/post_process_drawio.py` |
| `scripts/fix_icon_colors.py` | `plugins/deploy-on-aws/scripts/lib/fix_icon_colors.py` |
| `scripts/fix_nesting.py` | `plugins/deploy-on-aws/scripts/lib/fix_nesting.py` |
| `scripts/fix_step_badges.py` | `plugins/deploy-on-aws/scripts/lib/fix_step_badges.py` |
| `scripts/drawio_url.py` | `plugins/deploy-on-aws/scripts/lib/drawio_url.py` |
| `scripts/aws4-shapes.json` | `plugins/deploy-on-aws/scripts/lib/aws4-shapes.json` |
| `scripts/requirements.txt` | `plugins/deploy-on-aws/scripts/requirements.txt` |
| `scripts/validate-drawio.sh` | `plugins/deploy-on-aws/scripts/validate-drawio.sh` |
| `samples/example-agentcore.drawio` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/example-agentcore.drawio` |
| `samples/example-complex-platform.drawio` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/example-complex-platform.drawio` |
| `samples/example-event-driven.drawio` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/example-event-driven.drawio` |
| `samples/example-microservices.drawio` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/example-microservices.drawio` |
| `samples/example-multi-region-active-active.drawio` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/example-multi-region-active-active.drawio` |
| `samples/example-saas-backend.drawio` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/example-saas-backend.drawio` |
| `samples/example-sketch.drawio` | `plugins/deploy-on-aws/skills/aws-architecture-diagram/references/example-sketch.drawio` |
| `LICENSE-APACHE-2.0.txt` | `LICENSE` (repository root) |

### Note on aws4-shapes.json and sample .drawio files

JSON and binary/XML files cannot contain inline comments. Attribution for
`scripts/aws4-shapes.json` and `samples/*.drawio` is recorded exclusively
in this file (THIRD-PARTY-NOTICES.md) and in NOTICE.

### Modifications

Files have been copied verbatim with the following additions only:
- Python files: copyright/SPDX header block inserted after the shebang line
- Markdown files: HTML comment attribution block prepended
- No changes to logic, algorithms, or data content
