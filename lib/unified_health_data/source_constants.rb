# frozen_string_literal: true

module UnifiedHealthData
  # Canonical source identifiers used by the SCDF API response envelope.
  # These keys appear in the top-level response body (e.g. body['vista'], body['oracle-health'])
  # and are tagged onto each record's 'source' attribute for downstream consumers.
  module SourceConstants
    VISTA = 'vista'
    ORACLE_HEALTH = 'oracle-health'
  end
end
