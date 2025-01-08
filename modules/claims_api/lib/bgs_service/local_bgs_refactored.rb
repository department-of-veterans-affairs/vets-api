# frozen_string_literal: true

require 'claims_api/bgs_client'
require 'claims_api/bgs_client/definitions'
require 'bgs_service/local_bgs_refactored/find_definition'

module ClaimsApi
  class LocalBGSRefactored
    class << self
      delegate :breakers_service, to: BGSClient
    end

    def initialize(external_uid:, external_key:)
      external_uid ||= Settings.bgs.external_uid
      external_key ||= Settings.bgs.external_key

      @external_id =
        BGSClient::ExternalId.new(
          external_uid:,
          external_key:
        )
    end
  end
end
