# frozen_string_literal: true

module ClaimsApi
  class AutoEstablishedClaimSerializer < ActiveModel::Serializer
    attribute :token
    attribute :status
    attribute :evss_id

    # these attributes are added to match the serializer with the claims detail serializer
    attribute :date_filed
    attribute :min_est_date
    attribute :max_est_date
    attribute :open
    attribute :waiver_submitted
    attribute :documents_needed
    attribute :development_letter_sent
    attribute :decision_letter_sent
    attribute :requested_decision
    attribute :claim_type, default: 'Compensation'
    attribute :contention_list, default: []
    attribute :va_representative
    attribute :events_timeline, default: []
  end
end
