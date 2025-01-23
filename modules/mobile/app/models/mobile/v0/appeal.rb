# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    # This model is derived from the following docs: https://developer.va.gov/explore/api/appeals-status/docs?version=current
    # We do not use the endpoint that these docs are for but instead share the same upstream service.
    # The endpoint does not change the data in anyway so the docs should still be accurate.
    class Appeal < Common::Resource
      AOJ_TYPES = Types::String.enum(
        'vba',
        'vha',
        'nca',
        'other'
      )

      LOCATION_TYPES = Types::String.enum(
        'aoj',
        'bva'
      )

      PROGRAM_AREA_TYPES = Types::String.enum(
        'compensation',
        'pension',
        'insurance',
        'loan_guaranty',
        'education',
        'vre',
        'medical',
        'burial',
        'bva',
        'fiduciary',
        'other',
        'multiple',
        'vha',
        'voc_rehub',
        'voc_rehab'
      )

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
        'dro_hearing_no_show',
        'evidentiary_period',
        'ama_post_decision'
      )

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
        'ama_nod',
        'docket_change',
        'distributed_to_vlj',
        'bva_decision_effectuation',
        'dta_decision',
        'sc_request',
        'sc_decision',
        'sc_other_close',
        'hlr_request',
        'hlr_decision',
        'hlr_dta_error',
        'hlr_other_close',
        'statutory_opt_in'
      )

      LAST_ACTION_TYPES = Types::String.enum(
        'field_grant',
        'withdrawn',
        'allowed',
        'denied',
        'remand',
        'cavc_remand',
        'Granted',
        'dismissed_matter_of_law',
        'Dismissed',
        'Deferred',
        'Denied'
      )

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
        'merged',
        'evidentiary_period',
        'ama_remand',
        'post_bva_dta_decision',
        'bva_decision_effectuation',
        'sc_received',
        'sc_decision',
        'sc_closed',
        'hlr_received',
        'hlr_dta_error',
        'hlr_decision',
        'hlr_closed',
        'statutory_opt_in',
        'motion',
        'pre_docketed'
      )

      APPEAL_TYPES = Types::String.enum(
        'legacyAppeal',
        'appeal',
        'supplementalClaim',
        'higherLevelReview'
      )

      attribute :id, Types::String
      attribute :appealIds, Types::Array.of(Types::String)
      attribute :updated, Types::DateTime
      attribute :active, Types::Bool
      attribute :incompleteHistory, Types::Bool
      attribute :aoj, AOJ_TYPES
      attribute :programArea, PROGRAM_AREA_TYPES
      attribute :description, Types::String
      attribute :type, APPEAL_TYPES
      attribute :aod, Types::Bool.optional
      attribute :location, LOCATION_TYPES
      attribute :status do
        attribute :type, STATUS_TYPES
        attribute :details do
          attribute? :lastSocDate, Types::Date
          attribute? :certificationTimeliness, Types::Array.of(Integer)
          attribute? :ssocTimeliness, Types::Array.of(Integer)
          attribute? :decisionTimeliness, Types::Array.of(Integer)
          attribute? :remandTimeliness, Types::Array.of(Integer)
          attribute? :socTimeliness, Types::Array.of(Integer)
          attribute? :remandSsocTimeliness, Types::Array.of(Integer)
          attribute? :returnTimeliness, Types::Array.of(Integer)
        end
      end
      attribute :docket do
        attribute? :type, Types::String
        attribute? :month, Types::Date
        attribute? :switchDueDate, Types::Date
        attribute? :eligibleToSwitch, Types::Bool
      end
      attribute :issues, Types::Array do
        attribute :active, Types::Bool
        attribute :lastAction, LAST_ACTION_TYPES.optional
        attribute :description, Types::String
        attribute :diagnosticCode, Types::String.optional
        attribute :date, Types::Date
      end
      attribute :alerts, Types::Array do
        attribute? :type, ALERT_TYPES
        attribute? :details, Types::Hash
      end
      attribute :events, Types::Array do
        attribute :type, EVENT_TYPES
        attribute :date, Types::Date
      end
      attribute :evidence, Types::Array do
        attribute? :description, Types::String
        attribute? :date, Types::Date
      end
    end
  end
end
