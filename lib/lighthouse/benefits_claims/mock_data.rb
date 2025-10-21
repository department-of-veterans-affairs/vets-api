# frozen_string_literal: true

require 'test_helpers/title_generator_test_claims'

module BenefitsClaims
  # Mock data for Lighthouse responses - used for testing title generator mappings
  # Always enabled in development
  module MockData
    def self.enabled?
      Rails.env.development?
    end

    def self.get_claims_response
      {
        'data' => TitleGeneratorTestClaims.all_test_cases,
        'meta' => {
          'pagination' => {
            'currentPage' => 1,
            'perPage' => 10,
            'totalPages' => 3,
            'totalEntries' => 21
          }
        }
      }
    end

    def self.get_claim_response(id)
      claim = TitleGeneratorTestClaims.all_test_cases.find { |c| c['id'] == id }
      return nil if claim.nil?

      { 'data' => claim }
    end
  end
end
