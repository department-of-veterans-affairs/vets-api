# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    module Appeals
      class Event < Common::Resource
        EVENT_TYPES = Types::String.enum(
          'claim_decision',
          'nod',
          'soc',
          'form9',
          'ssoc',
          'certified',
          'hearing_held',
          'hearing_no_show',
          'bva_decision',
          'field_grant',
          'withdrawn',
          'ftr',
          'ramp',
          'death',
          'merged',
          'record_designation',
          'reconsideration',
          'vacated',
          'other_close',
          'cavc_decision',
          'ramp_notice',
          'transcript',
          'remand_return',
          'dro_hearing_held',
          'dro_hearing_cancelled',
          'dro_hearing_no_show'
        )

        attribute :type, EVENT_TYPES
        attribute :date, Types::Date
      end
    end
  end
end
