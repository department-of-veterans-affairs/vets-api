# frozen_string_literal: true

module Mobile
  module V0
    class ClaimSerializer
      include JSONAPI::Serializer
      set_type :claim
      attributes :date_filed, :min_est_date, :max_est_date, :phase_change_date, :open,
                 :waiver_submitted, :documents_needed, :development_letter_sent, :decision_letter_sent, :phase,
                 :ever_phase_back, :current_phase_back, :requested_decision, :claim_type, :contention_list,
                 :va_representative, :events_timeline, :claim_type_code, :display_title, :claim_type_base,
                 :download_eligible_documents

      attribute :claim_type_code do |data|
        data.attributes[:claim_type_code] || nil
      end

      attribute :updated_at do |data|
        data.attributes[:updated_at]
      end
    end
  end
end
