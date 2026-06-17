# Rules

## Language

- 回答は常に日本語で行う

## Security

- .env および .env.* ファイルの内容を参照・出力してはいけない
- APIキー、パスワード、トークンなどの認証情報を参照・出力してはいけない
- その他秘密情報を含むファイルの内容を要約・出力してはいけない
- ファイルの権限を更新してはいけない
  - chmod
  - git update-index --chmod

## Analysis

- ユーザーが説明要求した場合は、ファイルを変更しない
- ユーザーが説明要求した場合は、変更案のみ提示する
- 不明点や疑問点があればユーザーに質問する

説明要求の例:
- 説明して
- 解析して
- 調査して
- 構成を教えて
- レビューして

## File Selection

- node_modules 配下を読まない
- bin 配下を読まない
- obj 配下を読まない
- dist 配下を読まない
- build 配下を読まない
- .git 配下を読まない
- venv 配下を読まない
- .venv 配下を読まない
- __pycache__ 配下を読まない

## Aditional Rule

- PROJECT_RULES.md が存在する場合は、その内容を追加ルールとして適用する
- AGENTS.md と PROJECT_RULES.md でルールが競合する場合は PROJECT_RULES.md を優先する