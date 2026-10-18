# EverythingPage: historical PowerShell operations platform

EverythingPage brought device updates, infrastructure monitoring, help-desk workflows, and shared sessions into one browser-based operations surface. The original implementation used PowerShell HTTP listeners, runspaces, service watchdogs, CSV-backed state, database adapters, and custom browser interfaces.

This repository now presents **sanitized historical source**, rather than a deployable operations environment. The `.ps1.txt` references under `historical/` preserve the original control flow and numeric protocol templates. Operational strings and comments have been replaced, and datasets, keys, executables, process records, databases, spreadsheets, and deployment shortcuts are excluded from the current tree.

For runnable portfolio demonstrations derived from this work, see:

- [IPUAPI](https://github.com/Derek-Poe/IPUAPI): original binary command templates, synthetic packet fixtures, simulated dispatch, and observed-state reconciliation.
- [SitebossHub](https://github.com/Derek-Poe/SitebossHub): synthetic telemetry, historical data, and the original Canvas dashboard interactions in a portable application.

## What the original system implemented

| Source family | Engineering contribution |
| --- | --- |
| `historical/HelpDeskHub/` | HTTP request handling, alerts, account workflows, monitoring adapters, and a runspace-based API variant |
| `historical/IPU/` | Reconstructed outbound binary commands, update queues, completion checks, polling, and supervised service processes |
| `historical/SitebossHub/` | Sensor polling, history collection, alarm processing, report preparation, and API endpoints |
| `historical/AutoServerMonitor/` | Resource sampling, process discovery, and grouped service-control operations |
| `historical/WebSessionAPI/` | A shared session issuance, lookup, renewal, and persistence service |

The code illustrates an evolving system built around real operational constraints. It also contains historical limitations: shared file state, weak session-generation and expiration patterns, process-ID-based health checks, shared connection concerns, and administrative side effects. It should not be reused as a production authentication or administration service.

Read [the architecture notes](docs/ARCHITECTURE.md) and [sanitization boundaries](docs/SANITIZATION.md). The original application was not executed during this preparation. The references are deliberately inert, and replacing placeholders does not produce a supported deployment.

## Verify the reference package

From Windows PowerShell 5.1:

```powershell
./tools/Verify-References.ps1
```

This checks reference hashes and the absence of deployable scripts and data artifacts. It does not execute the historical source or establish its runtime correctness.

Current-tree cleanup does not erase previously published Git history. This repository makes no claim that earlier commits were scrubbed.

MIT license for Derek Poe's source. No third-party runtime binaries or original operational media are distributed in this reference tree.
