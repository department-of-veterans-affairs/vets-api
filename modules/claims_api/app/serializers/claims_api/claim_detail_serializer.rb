# frozen_string_literal: true

require_relative 'concerns/claim_base'
require_relative 'concerns/contention_list'
require_relative 'concerns/events_timeline'
require_relative 'concerns/va_representative'

module ClaimsApi
  class ClaimDetailSerializer
    include JSONAPI::Serializer
    include Concerns::ClaimBase
    include Concerns::ContentionList
    include Concerns::EventsTimeline
    include Concerns::VARepresentative

    set_type :claims_api_claim

    set_id do |object, params|
      params[:uuid] || object&.evss_id
    end

    attribute :status do |object|
      phase = phase_from_keys(object, 'claim_phase_dates', 'latest_phase_type')
      object.status_from_phase(phase)
    end

    attribute :supporting_documents do |object|
      object.supporting_documents.map do |document|
        {
          id: document[:id],
          type: 'claim_supporting_document',
          header_hash: document[:header_hash],
          filename: document[:filename],
          uploaded_at: document[:uploaded_at]
        }
      end
    end

    def self.object_data(object)
      object.data
    end
  end
end
