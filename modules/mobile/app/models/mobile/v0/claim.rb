# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Claim < Common::Resource
      attribute :id, Types::String
      attribute :date_filed, Types::Date
      attribute :min_est_date, Types::Date
      attribute :max_est_date, Types::Date
      attribute :phase_change_date, Types::Date
      attribute :open, Types::Bool
      attribute :waiver_submitted, Types::Bool
      attribute :documents_needed, Types::Bool
      attribute :development_letter_sent, Types::Bool
      attribute :decision_letter_sent, Types::Bool
      attribute :phase, Types::Integer
      attribute :ever_phase_back, Types::Bool
      attribute :current_phase_back, Types::Bool
      attribute :requested_decision, Types::Bool
      attribute :claim_type, Types::String
      attribute :contention_list, Types::Array
      attribute :va_representative, Types::String
      attribute :events_timeline, Types::Array.of(ClaimEventTimeline)
      attribute :updated_at, Types::Date
      attribute :claim_type_code, Types::String
      attribute :claim_type_base, Types::String
      attribute :display_title, Types::String
      attribute :download_eligible_documents, Types::Array
    end
  end
end
