# 八学科稳定版本：源码备份、完整历史与恢复说明

仓库：`miaotai7-lang/cn-math-taxonomy`。**仅备份本仓库的 `main`，不会下载上游待审核的内容到正式页面，更不会部署 Firebase。** 八学科学习网页继续从 `main` 的 `/ (root)` 发布。

## 备份内容（两种互补文件）

1. `cnm-main-<SHA>.zip`：在同一个已验证的稳定提交上导出的 Git 跟踪文件（HTML/JS/CSS/八学科 JSON/PWA/文档等）；**不带 Git 历史**。可用于恢复静态网站。
2. `cnm-history-<SHA>.bundle`：保留备份当时你自己仓库已获取的分支、标签和提交历史，能在原作者甚至自己的 GitHub 仓库不可访问时克隆出完整的版本历史。其内容只包含当时已存在、已获取的 Git refs，不保证包含作者将来的更新。
3. `SHA256SUMS.txt`（GitHub Actions）或 `manifest.json`（Windows）：完整性校验值，记录 `main` 的 Git SHA。

**数据边界**：它们不保存浏览器的 localStorage、孩子档案、诊断答题历史、其他设备的数据，也不保存 Firebase 中的数据。个人进度需另行使用网页自身的导出功能备份；导出后的恢复仍须实测。

## A. GitHub Actions 内置备份（短期、仍属于 GitHub）

新增 `.github/workflows/backup-stable.yml`，在 `main` 有提交后、每周日约 **09:42 日本时间**、或手动触发时执行。工作流只有 `contents: read` 权限；不创建标签，不推送分支，不发布网站。备份运行前验证现有网站文件、八学科 JSON、统计与二维码保护。然后：

- 从 `main` 导出 ZIP；制作包含已获取 refs 的 Git Bundle。
- 对 Git Bundle 进行校验，并克隆成临时仓库比较 `main` SHA。
- 检查 ZIP 文件完整性、关键网页文件、五份核心 JSON 文件。
- 生成 SHA-256 校验文件和版本说明，上传为 GitHub Actions Artifact。

**Artifact 保留期设置为 30 天**，实际期限还可能受到仓库/平台政策约束。不要把它当成永久备份。及时在 Actions 对应成功运行的 Artifacts 区下载，并复制到电脑之外的独立位置。

## B. Windows 独立备份（优先完成）

新电脑已经安装 Git for Windows。将交付包解压到固定目录，直接双击 `windows/BACKUP_NOW_WINDOWS.cmd`（普通权限，不需管理员）。

- 默认备份目录是 Windows **文档/Documents** 文件夹下的 `CNM_Source_Backups`；每次保留一个带 UTC 时间戳的新文件夹。
- 会从**你自己的公开 Fork** `https://github.com/miaotai7-lang/cn-math-taxonomy.git` 克隆全量仓库历史，绝不直接同步原作者网站。
- 每次保存源码 ZIP、Git Bundle、包含提交 SHA 与两份 SHA-256 的 `manifest.json`。
- 脚本会校验 ZIP 中必须存在八学科数据等文件，并从 Bundle 真实恢复到临时目录核对主分支 SHA。失败则报告错误，不把不完整文件夹视为有效备份。
- 双击 `windows/VERIFY_LATEST_WINDOWS.cmd` 可验证最近一次备份。
- 建议将整个时间戳文件夹复制到另一个硬盘、U 盘或独立云盘；只有电脑本机这一份仍有丢失风险。

**可选 Windows 周备份**：确认第一次手动备份成功后，双击 `windows/INSTALL_WEEKLY_BACKUP_WINDOWS.cmd`。它尝试在当前账户的任务计划程序中创建每周日 10:15 自动备份任务，脚本复制到 `%LOCALAPPDATA%\CNMSourceBackup`。仅在用户已登录 Windows 时可运行；电脑长期关闭、任务计划程序权限限制和 GitHub 不可达等情况会导致某次失败。**计划任务安装及运行尚待你的 Windows 电脑实测**。不要把周计划的成功当成外部云盘已经备份。

## C. 如何从备份恢复

**仅验证（不影响网站）**：在保存 `*.bundle` 与校验文件的目录内验证 SHA-256；然后执行 `git clone -b main <bundle路径> <新的空目录>`，核对克隆出的 `main` SHA 与 `manifest.json` 或 `RESTORE_INFO.txt`。

**重建网站（仅在明确授权后）**：将 ZIP 解压到全新、隔离的本地目录，用本地 HTTP 服务检查八学科入口、图谱、诊断、PWA、统计与分享链接。然后在新的独立测试仓库/域名恢复网页，实测通过并得到所有者明确许可后才能切换正式站点。**不得直接用 `git push --force` 改写现有 `main`；不得清空浏览器或 Firebase 数据**。

**如果需要回到较老的稳定版**：从 Git Bundle 中找出目标 SHA，在独立恢复分支检出并人工检查，而不是直接把整仓库恢复为最新或未审核的分支。发布后还必须在 Windows、Android、iPad 清理/更新 PWA Service Worker 的缓存验证旧版资源不会混用。

## D. 自动更新仍然需要人工审核

当前自动更新工作流 `.github/workflows/review-upstream.yml` 可能自动创建 Draft PR，**但绝不会自行合并**。在人工合并任何上游更新后，先运行备份工作流确认新稳定版可以恢复；若最新上游 `README.md` 删除了关于 AI 生成内容未经教师审核的重要提示，应在人工审查时保留准确的风险说明。项目根许可证为 CC BY-NC 4.0，署名及非商业条件仍然有效。

本备份模块不修改 `building-japanese-word-study` 主站仓库，完全不接触 Firebase 配置或账号私钥。
