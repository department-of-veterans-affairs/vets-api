# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    module Appeals
      class Status < Common::Resource
        STATUS_TYPES = Types::String.enum(
          'scheduled_hearing',
          'pending_hearing_scheduling',
          'on_docket',
          'pending_certification_ssoc',
          'pending_certification',
          'pending_form9',
          'pending_soc',
          'stayed',
          'at_vso',
          'bva_development',
          'decision_in_progress',
          'bva_decision',
          'field_grant',
          'withdrawn',
          'ftr',
          'ramp',
          'death',
          'reconsideration',
          'other_close',
          'remand_ssoc',
          'remand',
          'merged'
        )

        attribute :type, STATUS_TYPES
        attribute :details, Types::Hash
      end
    end
  end
end
