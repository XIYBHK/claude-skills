# Git 提交示例

本文档包含提交信息格式示例，作为生成提交信息的参考。scope 应根据实际项目模块名称填写。

## 提交格式

```
<type>(<scope>): <简述>

<详细描述（可选）>
```

## 格式示例

### 重构类 (refactor)

```
refactor(Core,Utils,Sort,Geometry): 代码审查修复 - 原子操作安全/数组越界/版本兼容

- Core: 修复原子操作使用平台API替代非原子实现
- Utils: 修复数组越界风险并移除重复定义
- Sort: 使用新宏适配版本兼容
- Geometry: 移除未使用的头文件
```

```
refactor(ObjectPool,Blueprint): 新增对象池统计命令并优化节点代码
```

```
refactor(Sampling): 优化代码结构并增强纹理采样功能
```

### 修复类 (fix)

```
fix(Sampling): 修复 CI 编译错误
```

```
fix(Sampling): 修复网格索引Bug并添加内存预分配
```

```
fix(Geometry): 移除模块依赖，修复 CI 构建失败
```

### 新功能类 (feat)

```
feat(Geometry): 新增基于形状组件的点阵生成功能，支持 Box/Sphere 形状和随机变换参数
```

```
feat(ObjectPool,Blueprint): 新增对象池统计命令并优化节点代码
```

### 文档类 (docs)

```
docs: 更新 CHANGELOG.md 格式
```

```
docs: 合并更新日志到 v1.9.4
```

```
docs(ci): 同步 CI 工作流配置更新
```

### 工具类 (chore)

```
chore: 将 CI 工作流的 powershell 替换为 pwsh
```

## Scope 命名建议

根据项目实际情况，scope 通常使用以下方式命名：

| 项目类型 | Scope 示例 |
|---------|-----------|
| 前端项目 | `components`, `hooks`, `utils`, `api`, `styles` |
| 后端项目 | `auth`, `database`, `api`, `middleware`, `config` |
| 游戏引擎 | `Core`, `Editor`, `Runtime`, `Blueprint`, `UI` |
| 通用库 | `core`, `utils`, `types`, `helpers` |

**原则**: scope 应简洁、能表达变更所属模块，多个模块用逗号分隔。
