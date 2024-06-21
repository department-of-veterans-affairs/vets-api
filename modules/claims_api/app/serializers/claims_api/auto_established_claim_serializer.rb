# frozen_string_literal: true

require_relative 'concerns/claim_base'
require_relative 'concerns/contention_list'
require_relative 'concerns/events_timeline'
require_relative 'concerns/va_representative'
require_relative 'concerns/phase'

module ClaimsApi
  class AutoEstablishedClaimSerializer
    include JSONAPI::Serializer
    include ClaimBase
    include ContentionList
    include EventsTimeline
    include VARepresentative
    include Phase

    set_type :claims_api_claim

    attributes :token, :status, :evss_id, :flashes

    set_id do |object|
      object&.id
    end

    def self.object_data(object)
      object.data
    end
  end
end
