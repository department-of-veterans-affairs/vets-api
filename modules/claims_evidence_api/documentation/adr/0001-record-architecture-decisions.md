# 1. Record architecture decisions

Date: 2024-06-14

## Status

Accepted

## Context

We need to record the architectural decisions made on this project.

## Decision Documentation

We will use Architecture Decision Records, as [described by Michael Nygard](http://thinkrelevance.com/blog/2011/11/15/documenting-architecture-decisions).

### Using adr-tools

This repository makes use of [adr-tools](https://github.com/npryce/adr-tools/tree/master) to record architectural decisions as part of the code base.

There are two uses for this, recording a new decision and superseding an existing decision.

#### Recording a new decision

To create a new decision use the adr new command:

```bash
 adr new <decision-title>
```

#### Superseding an existing decision

To overwrite an existing decision you can add the -s flag followed by which is getting overwritten. In this example we are overwriting decision 9 with an updated decision:

```bash
adr new -s 9 <decision-title>
```

## Consequences

See Michael Nygard's article, linked above. For a lightweight ADR toolset, see Nat Pryce's [adr-tools](https://github.com/npryce/adr-tools).
