# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class ClaimEstablisher
    include Sidekiq::Worker

    def perform(auto_claim_id)
      ClaimsApi::Form526Submitter.submit_claim(auto_claim_id)
    end
  end
end
