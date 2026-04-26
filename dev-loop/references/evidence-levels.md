# evidence-levels.md — A/B/C 证据等级判定与升级

## 判定标准

| 等级 | 证据类型 | 示例 |
|---|---|---|
| A | 官方一手来源 | context7 命中、官方文档 URL、GitHub release notes、源码行号 |
| B | 权威二手来源 | 知名开源项目代码、技术团队博客、Stack Overflow 高赞答案、公认 best practice |
| C | 未验证假设 | Claude 训练数据记忆、"应该是这样"、未查证的推测 |

## 升级流程（CR-2）

任何 `[C]` 必须按下列顺序尝试升级：

```
[C] → context7 查 latest docs？
  命中 → [A]，记 link
  未命中 → WebSearch 关键词
    找到权威来源 → [B]，记 link
    找不到 → 读相关开源项目源码
      找到 → [A]，记 repo+path+line
      仍然没有 → 保留 [C — 未验证]，同步写入 lessons.md 登记复查触发条件
```

## 典型反例（禁止）

- `"React 19 引入了 useOptimistic" [A]` ← 错，没给链接
- `"Prisma 支持 OR 查询" [A]` ← 错，太泛泛，没指到具体文档
- `"Postgres 是主流选型 [B]"` ← 错，"主流"不是证据

## 典型正例

- `"React 19 引入 useOptimistic [A — https://react.dev/reference/react/useOptimistic]"`
- `"Prisma 的 findMany 支持 where.OR 数组 [A — context7 /prisma/docs §where-operators]"`
- `"选 Postgres 而非 MySQL：Neon/Supabase 主流选 Postgres [B — https://neon.tech/docs]"`
