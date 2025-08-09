### **GitHub Actions 学习笔记**

#### **一、核心概念与工作流结构**

一个 GitHub Actions 工作流由一个放置在 `.github/workflows/` 目录下的 YAML 文件定义。其核心结构包括：

* `name`: 工作流的名称，显示在 GitHub Actions 页面。
* `on`: 触发工作流的事件。
* `jobs`: 工作流执行的任务，一个工作流可以包含一个或多个 `job`。
* `steps`: 组成 `job` 的一系列步骤。
* `runs-on`: `job` 运行的虚拟机环境。

**基础结构示例:**

```yaml
name: 'My First Workflow'
on: [push]
jobs:
  my_first_job:
    runs-on: ubuntu-latest
    steps:
      - name: 'Echo a message'
        run: echo 'Hello, world!'
```

---

#### **二、触发工作流 (Triggers)**

我们深入探讨了三种核心触发器：

1. **事件触发 (`on: push`)**: 当代码被推送到指定分支时运行。

    ```yaml
    on:
      push:
        branches: [ main, develop ] # 只有 main 和 develop 分支的 push 会触发
    ```

2. **定时触发 (`on: schedule`)**: 使用 `cron` 表达式在指定时间（UTC时间）运行。

    ```yaml
    on:
      schedule:
        # 每天 UTC 时间 0 点 30 分运行
        - cron: '30 0 * * *'
    ```

3. **手动触发 (`on: workflow_dispatch`)**: 在 Actions 页面提供一个 "Run workflow" 按钮，可手动触发并传入参数。

    ```yaml
    on:
      workflow_dispatch:
        inputs:
          branch:
            description: 'Branch to build from'
            required: true
            default: 'main'
    ```

---

#### **三、实战一：构建与推送 Docker 镜像**

这是一个经典的 CI/CD 流程，我们的目标是创建一个灵活的、可手动配置的工作流。

**最终代码示例 (`.github/workflows/build-docker.yml`):**

```yaml
name: 'Manual Build and Push Docker Image'

on:
  workflow_dispatch:
    inputs:
      image_name:
        description: 'Image name (e.g., my-username/my-app)'
        required: true
      image_tag:
        description: 'Image tag'
        required: true
        default: 'latest'
      branch:
        description: 'Branch to build from'
        required: true
        default: 'main'

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.inputs.branch }}

      - name: Log in to private registry
        uses: docker/login-action@v3
        with:
          registry: ${{ secrets.REGISTRY }}
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_TOKEN }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ secrets.REGISTRY }}/${{ github.event.inputs.image_name }}:${{ github.event.inputs.image_tag }}
```

**关键技术点解析:**

* **安全凭证**: 密码和令牌等敏感信息**必须**存储在仓库的 `Settings > Secrets and variables > Actions` 中，并通过 `${{ secrets.YOUR_SECRET }}` 语法引用。
* **完全限定镜像名称 (FQIN)**: 推送到私有仓库时，镜像的 `tags` 必须包含仓库地址的全路径，例如 `my-registry.com/my-app:latest`。这是 `login` 步骤和 `push` 步骤能正确协作的关键。
* **使用市场 Action**: 通过 `uses:` 复用 `actions/checkout`、`docker/login-action` 和 `docker/build-push-action` 等官方或社区验证过的 Action，可以极大简化工作流的编写，并提高稳定性。

---

#### **四、实战二：定时任务与结果持久化**

GitHub Actions 的运行器是临时的（无状态的），任务结束后所有文件都会被销毁。因此，结果持久化至关重要。

##### **方法 A: 提交回仓库 (适用于版本化数据)**

**场景**: 每天追踪数据变化，并保留完整的历史记录。

**最终代码示例 (`.github/workflows/track-data.yml`):**

```yaml
name: 'Track Data Daily'
on:
  schedule:
    - cron: '0 0 * * *'
  workflow_dispatch:

jobs:
  track-and-commit:
    runs-on: ubuntu-latest
    permissions:
      contents: write # 关键点：授予写权限
    steps:
      - uses: actions/checkout@v4

      - name: Generate result file
        run: echo "Data on $(date)" > daily_data.txt

      - name: Commit and push if content changed
        uses: stefanzweifel/git-auto-commit-action@v5
        with:
          commit_message: "feat: Update daily data"
          file_pattern: daily_data.txt
```

**关键技术点解析:**

* **写权限 (`permissions`)**: `git push` 操作需要对仓库内容的写权限。必须在 `job` 或 `workflow` 层面添加 `permissions: contents: write`。
* **专用 Action**: 使用 `stefanzweifel/git-auto-commit-action` 这类 Action 可以自动处理 `git` 配置、`add`、`commit` 和 `push` 的所有细节，非常便捷。

##### **方法 B: 使用产物 (适用于报告、日志、二进制文件)**

**场景**: 每天生成诊断报告，并能在 `job` 之间传递。

**最终代码示例 (`.github/workflows/run-diagnostics.yml`):**

```yaml
name: 'Run Daily Diagnostics and Notify'
on: [workflow_dispatch]

jobs:
  run-and-upload:
    runs-on: ubuntu-latest
    steps:
      - name: Generate diagnostic log
        run: echo "System check on $(date)" > diagnostic-log.txt
      - name: Upload diagnostic report
        uses: actions/upload-artifact@v4
        with:
          name: diagnostic-report
          path: diagnostic-log.txt
          retention-days: 5 # 产物保留5天

  notify-admin:
    needs: run-and-upload # 关键点：定义 job 依赖
    runs-on: ubuntu-latest
    steps:
      - name: Download diagnostic report
        uses: actions/download-artifact@v4
        with:
          name: diagnostic-report
      - name: Send notification (simulation)
        run: cat diagnostic-log.txt
```

**关键技术点解析:**

* **Job 隔离与依赖 (`needs`)**: 不同 `job` 运行在隔离的环境中。必须使用 `needs: [job_name]` 来定义它们的执行顺序，确保 `notify-admin` 在 `run-and-upload` 成功后才开始。
* **产物传递**: `actions/upload-artifact` 和 `actions/download-artifact` 是在 `job` 之间传递文件的标准方式。最新版的 `download-artifact` 会自动解压文件。

---

#### **五、Action 的工作原理**

一个 Action 是一个可复用的自动化单元，由 `action.yml` 文件定义，其核心是 `runs` 字段。

1. **JavaScript Action (`using: 'node20'`)**:
    * **原理**: 在 Node.js 环境中执行一个 JS 文件。
    * **优缺点**: 启动快，跨平台，官方工具包支持好。但受限于 Node.js 环境。
    * **代表**: `actions/checkout`。

2. **Docker 容器 Action (`using: 'docker'`)**:
    * **原理**: 在一个由 `Dockerfile` 定义的容器中执行代码。
    * **优缺点**: 环境完全自定义，语言无关。但启动慢，主要用于 Linux。
    * **代表**: `docker/login-action`。

3. **复合 Action (`using: 'composite'`)**:
    * **原理**: 将一系列 `steps` 封装成一个可复用的 Action。
    * **优缺点**: 极其简单，无需编程。但功能有限，适合线性流程。
    * **适用**: 将多处重复的 `steps` 序列提取成一个 Action。

---

#### **六、初学者易混淆的关键点（避坑指南）**

1. **YAML 缩进**: 必须使用2个空格，层级要对齐。
2. **Secrets vs. Variables**: `Secrets` 用于敏感信息（密码），`Variables` 用于非敏感配置（用户名）。
3. **Job 隔离**: 不同 `job` 间的文件传递**必须**用 `artifact`。
4. **默认权限**: `git push` 等写操作需要明确授予 `permissions: contents: write`。
5. **Action 版本**: 总是锁定到具体版本（`@v4`），不要用 `@main`。
6. **跨 Step 传环境变量**: 使用 `echo "VAR_NAME=value" >> $GITHUB_ENV`。
7. **`if` 条件**: 必须使用 GitHub 表达式语法（`${{...}}`），不是 Shell 语法。
8. **`schedule` 时区**: `cron` 表达式基于 **UTC** 时间。
9. **缓存 vs. 产物**: `Cache` 用于加速（如依赖包），`Artifact` 用于保存结果。
10. **`workflow_dispatch` 默认分支**: 手动触发默认在仓库的**主分支**上运行，需要 `inputs` 来选择其他分支。
