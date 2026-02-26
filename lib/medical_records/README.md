# Medical Records Logging Guide

## Overview

`MedicalRecords::MedicalRecordsLog` (`lib/medical_records/medical_records_log.rb`) is the structured logging utility for Medical Records V2. It provides:

- **Structured envelope** — every entry includes `service: 'medical_records'`, `resource:`, `action:`.
- **Automatic PII stripping** — 22 keys (ICN, SSN, email, user_uuid, edipi, etc.) recursively removed from all log output.
- **Tiered verbosity** — `info`, `warn`, `error` always-on; `diagnostic` gated by Flipper toggles.
- **Domain + global toggle fallback** — `diagnostic` checks a per-domain toggle first, falls back to the global toggle. Either one activates logging.

---

## Quick Start

```ruby
log = MedicalRecords::MedicalRecordsLog.new(user: current_user)

log.info(resource: MedicalRecordsLog::CLINICAL_NOTES, action: 'index', total: 12)       # always-on
log.diagnostic(resource: MedicalRecordsLog::CLINICAL_NOTES, action: 'filter', filtered: 8) # toggle-gated
log.warn(resource: MedicalRecordsLog::CLINICAL_NOTES, action: 'anomaly', rate: 85.0)      # always-on
log.error(resource: MedicalRecordsLog::CLINICAL_NOTES, action: 'show', error_message: 'timeout')
```

Use domain constants (`CLINICAL_NOTES`, `ALLERGIES`, `CONDITIONS`, `LABS_AND_TESTS`, `VACCINES`, `VITALS`) instead of raw strings.

---

## Feature Toggles

| Toggle                                           | Actor  | Purpose                                                   |
| ------------------------------------------------ | ------ | --------------------------------------------------------- |
| `:mhv_medical_records_clinical_notes_diagnostic` | `user` | Gates diagnostic logging for clinical notes               |
| `:mhv_medical_records_diagnostic_logging`        | `user` | Global fallback — enables diagnostics for **all** domains |

`diagnostic_enabled?` checks the domain toggle first, then the global. Enable the domain toggle for surgical per-user debugging; flip the global toggle during incidents.

**In tests**, always stub — never use `Flipper.enable`:

```ruby
allow(Flipper).to receive(:enabled?)
  .with(:mhv_medical_records_clinical_notes_diagnostic, user).and_return(true)
```

---

## Adding Logging for a New Domain

Clinical notes is the reference implementation. Follow these steps:

1. **Use a domain constant** — e.g. `MedicalRecordsLog::ALLERGIES` (already defined).

2. **Register a domain toggle** — add to `DOMAIN_TOGGLES` in `medical_records_log.rb`:

   ```ruby
   ALLERGIES => :mhv_medical_records_allergies_diagnostic,
   ```

3. **Add toggle to `config/features.yml`** (alphabetical order):

   ```yaml
   mhv_medical_records_allergies_diagnostic:
     actor_type: user
     description: Enables diagnostic logging for allergies. Falls back to mhv_medical_records_diagnostic_logging.
     enable_in_development: false
   ```

4. **Create a logging concern** — memoize `MedicalRecordsLog`, expose domain helpers, guard expensive computation with `return unless mr_log.diagnostic_enabled?(...)`.
   Reference: `lib/unified_health_data/concerns/clinical_notes_logging.rb`

5. **Include the concern** in the service class.

6. **Write specs** — stub toggles, assert `Rails.logger` receives structured hashes.
   Reference: `spec/lib/unified_health_data/concerns/clinical_notes_logging_spec.rb`

---

## Clinical Notes — Reference Implementation

### Service Concern (`lib/unified_health_data/concerns/clinical_notes_logging.rb`)

| Method                        | Logs                                       | Level        |
| ----------------------------- | ------------------------------------------ | ------------ |
| `log_notes_response_count`    | DocumentRef totals vs. parsed vs. filtered | `diagnostic` |
| `log_notes_index_metrics`     | VistA/OH counts, date range                | `diagnostic` |
| `log_notes_show_metrics`      | Source, found/not-found, note type         | `diagnostic` |
| `log_loinc_code_distribution` | LOINC code frequencies                     | `diagnostic` |
| `warn_high_filter_rate`       | >50% of DocumentRefs filtered              | `warn`       |
| `warn_date_parse_failures`    | ≥3 unparseable dates                       | `warn`       |

### Adapter (`lib/unified_health_data/adapters/clinical_notes_adapter.rb`)

Creates its own `MedicalRecordsLog` from `user:` — no parameter plumbing needed.

| Method                       | Logs                                  | Level        |
| ---------------------------- | ------------------------------------- | ------------ |
| `log_filtered_clinical_note` | FHIR `id`, `docStatus`, filter reason | `diagnostic` |
| empty content warning        | Note passes filter but has no content | `warn`       |
| unknown LOINC warning        | Code not in known mapping             | `warn`       |

### StatsD Metrics (Always On)

Gauges: `unified_health_data.clinical_notes.index.{total,vista,oracle_health}`
Counters: `...show.source`, `...show.not_found`, `...filtered`, `...anomaly.high_filter_rate`, `...anomaly.date_parse_failures`, `...clinical_note.empty_content`, `...clinical_note.unknown_loinc_code`

---

## Key Files

| File                                                                   | Purpose                                         |
| ---------------------------------------------------------------------- | ----------------------------------------------- |
| `lib/medical_records/medical_records_log.rb`                           | Core utility — PII stripping, toggles, envelope |
| `lib/unified_health_data/concerns/clinical_notes_logging.rb`           | Reference concern implementation                |
| `lib/unified_health_data/adapters/clinical_notes_adapter.rb`           | Adapter-level logging                           |
| `spec/lib/medical_records/medical_records_log_spec.rb`                 | Unit tests (23 examples)                        |
| `spec/lib/unified_health_data/concerns/clinical_notes_logging_spec.rb` | Concern specs                                   |
| `spec/lib/unified_health_data/service_spec.rb`                         | Integration tests for toggle fallback           |
