# frozen_string_literal: true

module ClaimFastTracking
  module DiagnosticCodesForMetrics
    include DiagnosticCodes

    DC = [
      LIMITED_MOTION_OF_WRIST,
      LIMITATION_OF_MOTION_OF_INDEX_OR_LONG_FINGER,
      LIMITATION_OF_EXTENSION_OF_THE_THIGH,
      FLATFOOT_ACQUIRED,
      HALLUX_VALGUS_UNILATERAL,
      TINNITUS,
      SCARS_GENERAL,
      MIGRAINES
    ].freeze
  end
end
