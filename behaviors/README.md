# behaviors

A behavior is a named bundle of parts (skills, agents, hooks, library docs) that deploy together.

Each behavior lives in its own directory with a `behavior.md` manifest:

```
behaviors/
└── example/
    └── behavior.md
```

Manifest format is provisional:

```markdown
---
name: example
description: One line on what this behavior changes about how Claude works.
parts:
  skills: [skills/some-skill]
  agents: [agents/some-agent.md]
  hooks: [claude/hooks/some-hook]
  library: [library/some-doc.md]
---

Optional prose: intent, when to use it, caveats. This body can double as the
instruction fragment injected on deploy (into `AGENTS.md`, which `CLAUDE.md` imports).
```
