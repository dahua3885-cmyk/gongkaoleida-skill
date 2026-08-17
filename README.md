# gongkaoleida-skill

一个用于扫描、核验和筛选广西公考及广义招聘公告的 Codex Skill，供团队内部共享源码和协作维护。

本仓库直接镜像当前生产使用版本，完整保留客户名称、运营者标注、本地项目路径、评分演进记录和业务沉淀规则，不做公开发布所需的脱敏或通用化改写。

它把“找公告—核验原文—判断是否值得做内容—整理交付表”串成一套可审计流程，默认覆盖公考雷达、广西人事考试网、14 个设区市人社/政府招聘入口和广西人才网地市站。

## 主要能力

- 扫描公考雷达近三天公告，并处理登录态、分页和列表完整性。
- 固定巡检广西官方招聘入口，保留来源、发布日期和核验状态。
- 回到公告正文及附件核验人数、学历、编制、报名时间等关键字段。
- 对通过硬门槛的公告统一评分，对排除项明确记录原因。
- 从成绩、资格审查、体检和拟聘名单中发现可公开验证的数据型内容素材。
- 输出公告总表、名单素材总表和来源审计记录。
- 提供交付文档与审计台账校验脚本。

## 安装

### 推荐：让 Codex 自动安装

先确认自己的 GitHub 账号已经获得本私有仓库的访问权限，并在本机完成 GitHub 登录。然后在 Codex 中发送：

```text
使用 $skill-installer，从私有仓库 dahua3885-cmyk/gongkaoleida-skill 的 gongkaoleida 路径安装 Skill。
```

Codex 会把 Skill 安装到 `$CODEX_HOME/skills/gongkaoleida`；下一轮对话即可使用。

### 手动安装

克隆私有仓库：

```bash
git clone https://github.com/dahua3885-cmyk/gongkaoleida-skill.git
```

将仓库中的 `gongkaoleida` 目录复制到你的 Codex Skills 目录，例如：

```text
~/.codex/skills/gongkaoleida
```

重新启动 Codex 或刷新 Skills 后使用。如果仓库无法打开或克隆，先让仓库管理员把你的 GitHub 账号加入 Collaborators 或所属团队。

## 使用示例

```text
使用 $gongkaoleida 扫描近三天广西公告，并输出两张按评分降序排列的总表。
```

也可以补充地区、公告类别、时间范围、交付目录等限制。

## 运行要求

- 能使用浏览器访问公开网页的 Codex 环境。
- Node.js 18+，用于运行官方来源扫描脚本。
- PowerShell 7 或 Windows PowerShell，用于运行现有校验脚本。
- 公考雷达完整分页可能需要你在浏览器中自行登录；本仓库不包含账号、Cookie 或其他凭据。

## 目录结构

```text
gongkaoleida/
├── SKILL.md
├── agents/
│   └── openai.yaml
├── references/
│   ├── collection-workflow.md
│   ├── content-performance-calibration.md
│   ├── list-content-rules.md
│   ├── official-sources.md
│   ├── output-contract.md
│   └── selection-rules.md
└── scripts/
    ├── scan_official_sources.mjs
    ├── validate_audit_ledger.ps1
    └── validate_delivery.ps1
```

## 内部共享说明

- 仓库包含内部项目名称、人员标注和本机绝对路径，只能放入受控的私有仓库。
- 安装目录中的 `gongkaoleida` 应与当前生产 Skill 保持完整镜像，修改前先核对是否会丢失业务规则。
- 如将来需要向互联网公开发布，应另建公开发行分支并重新完成隐私、凭据、版权和路径审计。

## 数据与合规边界

- 只处理公开招聘信息，并尽量回到官方正文和附件核验。
- 不绕过登录、验证码、访问控制或站点安全机制。
- 不收集、提交或分享账号密码、Cookie、Token 等凭据。
- 使用者应遵守目标网站的服务条款、robots 规则及适用法律。
- 评分用于内容运营排序，不代表岗位客观价值，也不构成报考建议。

## 使用许可

仅限授权团队内部使用，详见 [LICENSE](LICENSE)。
