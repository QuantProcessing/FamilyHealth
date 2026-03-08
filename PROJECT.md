# FamilyHealth — 项目文档

> **家庭健康管理 iOS App + Go 后端**
> 本文档用于记录当前项目的设计、规划、完成进度和待办事项，供接手的开发者（或 AI）快速理解项目并继续开发。

---

## 1. 项目概述

FamilyHealth 是一款以**隐私优先、本地为主**的家庭健康管理应用，核心功能包括：

1. **体检报告管理** — 拍照/相册上传报告，3 步流程
2. **病例记录** — 症状标签 + 用药子表单
3. **家庭组** — 创建（最多 2 个）、QR 二维码邀请、管理员可查看成员报告
4. **AI 健康助手** — 用户自配 API (OpenAI 兼容)，基于本地健康数据 RAG 增强
5. **双模式** — 默认本地模式（SwiftData），支持切换联网模式（Go REST API）
6. **中英文** — Localizable.strings

---

## 2. 当前完成进度

| 里程碑 | 状态 | 内容 |
|--------|------|------|
| **M1** | ✅ | 项目骨架、SwiftData 11 模型、5 Tab 导航、Onboarding/Login |
| **M2** | ✅ | 3 步报告上传 (PhotosPicker)、报告详情、病例录入/详情、ShipSwift 组件库 |
| **M3** | ✅ | 家庭组 CRUD、QR 码生成/扫描 (AVFoundation)、管理员查看成员报告 |
| **M4** | ✅ | OpenAI 兼容客户端 (SSE 流式)、LocalAIService RAG、AI 对话界面 |
| **M5** | ✅ | Go 服务端：Gin + GORM + JWT + 全量 API Handler |
| **M6** | ✅ | iOS Remote Services (APIClient + 4 个远程实现)、Docker 部署 |
| **M7** | ✅ | 中英文 Localizable.strings、Dockerfile (multi-stage) + docker-compose |

---

## 3. 项目结构

### 3.1 iOS App（45 文件）

```
FamilyHealth/
├── App/
│   ├── FamilyHealthApp.swift       # @main, SwiftData ModelContainer 配置
│   ├── AppState.swift              # 全局状态: mode, onboarding, userId, serverURL
│   └── ServiceContainer.swift      # DI 容器: Local ↔ Remote 切换
├── Models/                         # SwiftData @Model (6 文件 → 11 模型)
│   ├── User.swift                  # User
│   ├── HealthReport.swift          # HealthReport + ReportFile
│   ├── MedicalCase.swift           # MedicalCase + Medication + CaseAttachment
│   ├── FamilyGroup.swift           # FamilyGroup + FamilyMember
│   ├── AIModelConfig.swift         # AI 模型配置 (API Key 存 Keychain)
│   └── ChatConversation.swift      # ChatConversation + ChatMessage
├── Services/
│   ├── Protocols/
│   │   └── ServiceProtocols.swift  # 5 个协议: Auth/Report/Case/Family/AI
│   ├── Local/
│   │   ├── LocalAuthService.swift
│   │   ├── LocalReportService.swift
│   │   ├── LocalCaseService.swift
│   │   └── LocalFamilyService.swift
│   ├── AI/
│   │   ├── OpenAIClient.swift      # HTTPClient: 非流式 + SSE 流式
│   │   └── LocalAIService.swift    # RAG 管线: 搜索健康数据 → 增强 prompt → 流式返回
│   └── Remote/
│       ├── APIClient.swift         # 通用 HTTP Client (JWT + 泛型解码)
│       └── RemoteServices.swift    # Auth/Report/Case/Family 远程实现
├── Utilities/
│   ├── KeychainManager.swift       # API Key / Auth Token 安全存储
│   └── QRCodeGenerator.swift       # Core Image QR 码生成
├── Views/
│   ├── RootView.swift              # Onboarding → Login → MainTabView 路由
│   ├── MainTabView.swift           # 5 Tab: 首页/档案/AI/家庭/设置
│   ├── Onboarding/
│   │   ├── OnboardingView.swift    # 3 页引导
│   │   └── LoginView.swift         # 手机号 + 模式选择
│   ├── Home/
│   │   └── HomeView.swift          # 统计卡片 + 快捷操作 + 最近记录
│   ├── Records/
│   │   ├── RecordsView.swift       # 报告/病例列表 + 搜索 + FAB
│   │   ├── UploadReportView.swift  # 3 步上传 (SWStepper + PhotosPicker)
│   │   ├── ReportDetailView.swift  # 图片轮播 + AI 分析卡
│   │   ├── AddCaseView.swift       # 症状标签 + 用药子表单
│   │   └── CaseDetailView.swift    # 诊断 + FlowLayout 展示
│   ├── AI/
│   │   ├── AIChatListView.swift    # 对话列表 + 删除
│   │   └── AIChatView.swift        # 流式聊天 + 快捷提问 + 自动滚动
│   ├── Family/
│   │   ├── FamilyListView.swift    # 家庭组列表 + 创建 + 管理员查看成员报告
│   │   ├── QRScannerView.swift     # AVFoundation 扫码 (UIKit 桥接)
│   │   └── QRInviteView.swift      # QR 码展示 + 分享 + 复制
│   ├── Settings/
│   │   └── SettingsView.swift      # 运行模式 + AI 模型 CRUD + 关于
│   └── Components/                 # ShipSwift 风格组件库 (SW 前缀)
│       ├── SWShimmer.swift         # .swShimmer() 骨架屏
│       ├── SWLoading.swift         # 脉冲加载 + 骨架卡片
│       ├── SWStepper.swift         # 多步表单指示器
│       ├── SWAlert.swift           # .swAlert() Toast 通知
│       └── SWComponents.swift      # SWCard/SWBadge/SWAvatar/SWEmptyState/...
└── Resources/
    ├── zh-Hans.lproj/Localizable.strings  # 简体中文
    └── en.lproj/Localizable.strings       # English
```

### 3.2 Go 服务端（8 文件 + 部署）

```
server/
├── cmd/server/main.go            # 入口: DB migrate + DI + 路由
├── internal/
│   ├── config/config.go          # 环境变量配置
│   ├── model/
│   │   ├── models.go             # 11 GORM 模型
│   │   └── types.go              # PostgreSQL text[] 适配
│   ├── middleware/middleware.go   # JWT 认证 + CORS
│   ├── repository/repositories.go# 5 Repo: User/Report/Case/Family/Chat
│   ├── service/services.go       # 5 Service: Auth(JWT)/Report/Case/Family(邀请码)/AI
│   └── handler/handlers.go       # 全量 HTTP Handler
├── Dockerfile                    # 多阶段构建 (golang → alpine)
└── go.mod

docker-compose.yml (项目根目录)    # PostgreSQL+pgvector, Redis, MinIO, Go API
```

---

## 4. 架构设计

### 4.1 核心架构图

```
┌──────────────────────── iOS App ────────────────────────┐
│                                                          │
│   SwiftUI Views → ServiceContainer → Local/Remote Svc    │
│                         ↓                                │
│              ┌─── Local Mode ────┐  ┌── Remote Mode ──┐  │
│              │ SwiftData         │  │ APIClient → REST │  │
│              │ Keychain          │  │                  │  │
│              │ FileManager       │  │                  │  │
│              └───────────────────┘  └──────────────────┘  │
│                                            │              │
│              ┌─── AI Service ────┐         │              │
│              │ OpenAIClient      │         │              │
│              │ RAG (本地搜索)    │         │              │
│              │ → 用户配置的 API  │         │              │
│              └───────────────────┘         │              │
└────────────────────────────────────────────┼──────────────┘
                                             │
                                     ┌───────▼───────┐
                                     │  Go Server     │
                                     │  Gin + GORM    │
                                     │  JWT Auth      │
                                     ├───────────────┤
                                     │  PostgreSQL    │
                                     │  + pgvector    │
                                     │  Redis         │
                                     │  MinIO         │
                                     └───────────────┘
```

### 4.2 数据流

- **本地模式**: View → Service Protocol → LocalService → SwiftData → 本地磁盘
- **联网模式**: View → Service Protocol → RemoteService → APIClient → Go Server → PostgreSQL
- **AI 对话**: View → LocalAIService → 搜索本地健康数据(RAG) → 构建增强 prompt → OpenAIClient → 用户配置的 API

### 4.3 关键设计决策

| 决策 | 选择 | 原因 |
|------|------|------|
| 存储 | SwiftData | Apple 原生, 比 Core Data 更现代 |
| AI 集成 | 用户自配 API (无内置模型) | 用户可选 OpenAI/Claude/Ollama 等任何兼容端点 |
| 密钥存储 | iOS Keychain | 安全隔离, 不进入 SwiftData |
| 家庭组限制 | 最多 2 组 | 产品需求 |
| 邀请方式 | QR 码 + 手机号 | QR 码本地可用, 手机号需要联网 |
| 远程存储 | MinIO (S3 兼容) | 自托管, 数据自主 |
| 数据库 | PostgreSQL + pgvector | 关系型 + 向量搜索 |

---

## 5. API 接口总览

所有接口前缀: `/api/v1`, 需要 JWT 认证 (除 auth 外)

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/auth/sms-code` | 发送验证码 |
| POST | `/auth/login` | 登录/注册 |
| GET | `/users/me` | 获取当前用户 |
| PUT | `/users/me` | 更新用户信息 |
| POST | `/reports` | 创建报告 |
| GET | `/reports` | 报告列表 (分页) |
| GET | `/reports/:id` | 报告详情 |
| DELETE | `/reports/:id` | 删除报告 |
| POST | `/reports/:id/analyze` | AI 分析报告 |
| POST | `/cases` | 创建病例 |
| GET | `/cases` | 病例列表 (分页) |
| GET | `/cases/:id` | 病例详情 |
| DELETE | `/cases/:id` | 删除病例 |
| POST | `/families` | 创建家庭组 |
| GET | `/families` | 我的家庭组列表 |
| GET | `/families/:id` | 家庭组详情 |
| DELETE | `/families/:id` | 解散家庭组 |
| POST | `/families/:id/invite` | 手机号邀请 |
| POST | `/families/:id/qrcode` | 生成 QR 邀请码 |
| POST | `/families/join` | 通过邀请码加入 |
| GET | `/families/:id/reports` | 查看成员报告 (管理员) |
| POST | `/ai/chat` | AI 对话 |
| GET | `/ai/conversations` | 对话列表 |
| DELETE | `/ai/conversations/:id` | 删除对话 |

---

## 6. 接下来需要做什么 (TODO)

### 🔴 高优先级 — 需要在 Mac 上首先完成

1. **Xcode 项目配置**
   - 打开 Xcode, 创建 FamilyHealth.xcodeproj (如未创建)，将所有 Swift 文件添加到 target
   - 设置 Info.plist:
     - `NSCameraUsageDescription` = "用于扫描二维码和拍摄体检报告"
     - `NSPhotoLibraryUsageDescription` = "用于选择体检报告图片"
   - 设置 Deployment Target: iOS 17.0+
   - 添加 Capability: Keychain Sharing

2. **编译修复**
   - 所有代码在 Linux 上编写, 未经 `xcodebuild` 编译, 可能存在以下问题:
     - `@Query` macro 用法需要 SwiftData import
     - `UIImage` 在 SwiftUI 中需要桥接
     - Service 协议方法签名与实现之间可能有细微不匹配
     - `ServiceContainer` 的 `@Observable` 宏可能需要调整
   - **建议**: 逐模块编译 (Models → Services → Views), 逐步修复

3. **数据模型补全**
   - `HealthReport` 和 `MedicalCase` 目前未实现 `Codable` 用于远程传输
   - `ChatMessage.referenceIds` 可能需要在模型中添加

### 🟡 中优先级 — 功能完善

4. **ViewModel 层**
   - 当前 Views 直接使用 `@Query` + Service, 缺少专门的 ViewModel
   - 建议为复杂页面 (HomeView, RecordsView, AIChatView) 抽取 ViewModel

5. **文件加密存储**
   - `CryptoManager.swift` 尚未实现 (技术设计中规划了 AES-256-GCM)
   - 报告图片目前明文存储在 Documents 目录

6. **AI 功能增强**
   - 报告 OCR 文本提取 (Vision framework) 未实现
   - 向量存储 (本地 RAG) 目前用关键词搜索替代, 可集成 sqlite-vss
   - 服务端 AI 转发 (SSE proxy) 为 placeholder

7. **报告编辑功能**
   - ReportDetailView 的"编辑"按钮目前是 placeholder

8. **家庭组成员管理完善**
   - 成员显示名称目前用 UUID 前缀, 需要查询 User 数据获取真实姓名
   - 转让管理员功能未实现
   - 手机号邀请需对接真实用户查找

### 🟢 低优先级 — 优化和部署

9. **Go 服务端**
   - 运行 `go mod tidy` 生成 go.sum
   - `AuthService` 需要暴露 repos 为 public 或提供 getter (handler.go 中直接访问了 private 字段)
   - SMS 验证码集成 (阿里云/腾讯云)
   - MinIO 文件上传 handler
   - AI SSE 流式转发完善

10. **测试**
    - Unit Tests (Services + Repositories)
    - UI Tests (核心流程: 登录 → 上传报告 → AI 对话)

11. **部署**
    - `docker compose up -d` 一键启动, 需要测试
    - 生产环境 JWT_SECRET 必须修改

---

## 7. 环境依赖

### iOS
- Xcode 15+ (Swift 5.9+)
- iOS 17.0+ Deployment Target
- 第三方依赖 (SPM): 暂无, 均使用系统框架
  - 可选: Kingfisher (图片缓存), MarkdownUI (AI 回复渲染)

### Go 服务端
- Go 1.22+
- 依赖见 `server/go.mod`:
  - Gin, GORM, golang-jwt, google/uuid, lib/pq, minio-go 等
- Docker / Docker Compose

### 部署
```bash
# 启动服务端
docker compose up -d

# 验证
curl http://localhost:8080/health
# {"status":"ok"}
```

---

## 8. 技术文档索引

| 文档 | 位置 | 内容 |
|------|------|------|
| 技术方案设计 (详细) | `.gemini/antigravity/brain/.../technical_design.md` | 完整架构、SQL Schema、API 详细设计 |
| 产品设计 | `.gemini/antigravity/brain/.../product_design.md` | 需求分析、用户流程 |
| 实施计划 | `.gemini/antigravity/brain/.../implementation_plan.md` | 里程碑规划 |
