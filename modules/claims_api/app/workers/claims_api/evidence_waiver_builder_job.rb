# frozen_string_literal: true

require 'sidekiq'
require 'claims_api/evidence_waiver_pdf/pdf'

module ClaimsApi
  class EvidenceWaiverBuilderJob
    include Sidekiq::Worker

    # Generate a 5103 "form" for a given veteran.
    #
    # @param power_of_attorney_id [String] Unique identifier of the submitted POA
    def perform(target_veteran:, response: true)
      waiver = ClaimsApi::EvidenceWaiver.new(target_veteran: target_veteran)
      output_path = waiver.construct(response: response) # rubocop:disable Lint/UselessAssignment
      # upload `output_path` here (and remove rubocop:disable above)
    end
  end
end
