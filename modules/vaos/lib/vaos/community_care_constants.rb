# frozen_string_literal: true

module VAOS
  # Constants used specifically for Community Care Appointments logging, metrics, and service identification
  # This module only contains constants that are shared across multiple files.
  # Constants used in only one file should remain local to that file.
  module CommunityCareConstants
    # Service identification constants
    CC_APPOINTMENTS = 'Community Care Appointments'
    COMMUNITY_CARE_SERVICE_TAG = 'service:community_care_appointments'

    # StatsD metric prefixes for Community Care Appointments
    STATSD_PREFIX = 'api.vaos'
  end
end
