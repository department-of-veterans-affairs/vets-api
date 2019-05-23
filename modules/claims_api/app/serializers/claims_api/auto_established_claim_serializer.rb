# frozen_string_literal: true

module ClaimsApi
  class AutoEstablishedClaimSerializer < ActiveModel::Serializer
    attributes :token, :status, :evss_id

    # these attributes are added to match the serializer with the claims detail serializer
    attributes :date_filed, :min_est_date, :max_est_date, :open, :waiver_submitted,
               :documents_needed, :development_letter_sent, :decision_letter_sent,
               :requested_decision, :va_representative
    attribute :claim_type, default: 'Compensation'
    attribute :contention_list, default: []
    attribute :events_timeline, default: []
  end
end
