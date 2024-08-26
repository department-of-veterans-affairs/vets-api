# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    module Appeals
      class Alert < Common::Resource
        ALERT_TYPES = Types::String.enum(
          'form9_needed',
          'scheduled_hearing',
          'hearing_no_show',
          'held_for_evidence',
          'cavc_option',
          'ramp_eligible',
          'ramp_ineligible',
          'decision_soon',
          'blocked_by_vso',
          'scheduled_dro_hearing',
          'dro_hearing_no_show'
        )

        attribute :type, ALERT_TYPES
        attribute :details, Types::Hash
      end
    end
  end
end
