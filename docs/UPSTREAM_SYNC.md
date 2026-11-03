# 八学科知识图谱：受控上游更新与备份

适用仓库：`miaotai7-lang/cn-math-taxonomy`（公开 Fork）  
上游：`xiaoyang111222/cn-math-taxonomy`  
**稳定发布分支：`main`，GitHub Pages 从 `main` 的 `/ (root)` 发布。**

## 现有个人保护修改

- `assets/stats-config.js`：`cloudflareToken` 与 `endpoint` 都留空，不向作者统计 Worker 发送访问事件。
- `diagnose/share.js`：分享网址由 `new URL('../?from=share', window.location.href).href` 生成，指向自己网站。
- `LICENSE`：保留原始 CC BY-NC 4.0 署名和非商业使用限制；`package.json` 的 `ISC` 元数据与根许可证不同，不能据此推定所有内容都可以商业使用。
- 原作者的推广和外链可能仍存在；上线/每次上游更新都要人工复核。

## 工作流功能及边界

`.github/workflows/review-upstream.yml` 每日约 **日本时间 09:27** 尝试检查原作者的 `main`，也支持手动运行。

1. 在 GitHub Actions Runner 检出**自己仓库的** `main`，先检验和复制可信检查程序。
2. 拉取上游 `main`，检查是否有新的提交。
3. 若已有一个尚未审核的上游 PR，则停止本次更新，避免重复 PR。
4. 在新的 `review/upstream-<SHA>` 分支合并上游。不自动修改 `main`。
5. 若冲突、检测到 GitHub Actions 工作流/检查程序被改变、任一 JSON 无效、统计上报恢复或分享地址恢复作者域名，**停止，不发布该候选**。
6. 仅运行静态检查，不执行本次上游代码中的 Python/JS 脚本。
7. 检查通过则推送候选分支，创建 **Draft Pull Request**，由所有者人工审查。

**不会自动合并、发布、部署 Firebase、清空学习记录，也不会修改 `building-japanese-word-study` 仓库。** GitHub Pages 对 `main` 的任何合并提交可能自动重新发布，因此批准合并等同批准更新站点。

## 首次启用步骤

1. 在本仓库审阅含该工作流的 PR，确认只新增 `.github/workflows/review-upstream.yml`、`tools/check_upstream_candidate.py`、`tests/test_upstream_candidate.py` 和本文件。
2. 手动合并这份**设置工作流**的 PR（不改变网页文件）。GitHub Pages 可能重新构建，但用户页面内容不变。
3. 若 Actions 显示 disabled，在 **Actions** 页面启用本 Fork 的工作流；到 **Settings → Actions → General → Workflow permissions**，按需要允许 `Read and write permissions` 和 `Allow GitHub Actions to create and approve pull requests`。这些权限只为候选分支和 PR，不应让机器人合并 PR。
4. 打开 **Actions → Review upstream updates (never auto-merge) → Run workflow**，先手动验证一次。首次可能显示“No new upstream commits”，这是正常状态。
5. 每次收到 Draft PR，审核代码、外链和数据；记录 SHA/版本，下载仓库 ZIP，验证后才手动合并。

## 作者删除仓库、上游断线或更新失败时

- 当前公开 Fork 及其 `main` 文件不会因为工作流 `git fetch` 失败而被改动；但定期检查会失败，不能再收到作者的新版本。
- 已保留的 GitHub ZIP 是**独立代码副本**，但不会保存完整 Git 提交历史，也**不会备份浏览器 localStorage/孩子档案/答题历史**。此类个人数据需使用站内导出（若有）或独立备份，并测试导入。
- 每次手动通过新版本后，建议同时保存**离线 ZIP + Git 标签/提交 SHA**。在仓库外另存一份 ZIP；云端仓库或 GitHub 历史不能作为唯一备份。
- 回滚时应回到某个已测试通过的完整 Git 提交，再通过合规的正常提交或发布流程恢复，不强行重置 `main` 或删除学习记录。PWA Service Worker 缓存也需要重新验证。

## 目前没有验证的部分

- GitHub Actions 在用户账号下是否启用、是否有 PR 创建权限、定时调度是否按预期运行。
- 原作者新增任何题目/图谱时的语义正确性；JSON 能解析不代表课程内容准确。
- Windows/Android/iPad 的实际交互、第三方存储/PWA 缓存、孩子档案数据导入与恢复。
- 作者的其他外链、站外资源及新增代码的完整安全性。

**安全原则：通过静态测试也只能进入待审核 PR，不能自动合并上游到已发布的网站。**
