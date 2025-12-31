# frozen_string_literal: true

# Interface for a BenefitsClaimsProvider
#
# Include this module in a new ClaimsProvider class to define a standardized interface
# for fetching benefits claims data from various sources.
#
# @example Implementing a new claims provider
#   class MyClaimsProvider
#     include BenefitsClaimsProvider
#
#     def initialize(current_user)
#       @current_user = current_user
#     end
#
#     def get_claims
#       raw_claims = fetch_from_my_api
#       transform_to_dto(raw_claims)
#     end
#
#     def get_claim(id)
#       raw_claim = fetch_single_claim_from_my_api(id)
#       transform_to_dto(raw_claim)
#     end
#
#     private
#
#     def transform_to_dto(data)
#       # Transform your data source format to ClaimResponse DTO format
#     end
#   end
#
# Testing your provider implementation
#   RSpec.describe MyClaimsProvider do
#     let(:current_user) { create(:user) }
#
#     # This shared example enforces the BenefitsClaimsProvider interface contract
#     it_behaves_like 'benefits claims provider'
#
#     # Then add your provider-specific tests
#     describe '#get_claims' do
#       it 'returns claims from my API' do
#         # Your specific implementation tests
#       end
#     end
#   end
#
# The new class MUST implement these methods to be a valid BenefitsClaimsProvider:
# - get_claims: Returns an array of claims for the current user
# - get_claim(id): Returns a single claim by its ID
#
module BenefitsClaims
  module Providers
    module BenefitsClaimsProvider
      # Retrieves all claims for the current user
      #
      # @return [Array<Hash>] Array of claim data transformed to ClaimResponse DTO format
      def get_claims = raise(NotImplementedError)

      # Retrieves a single claim by ID
      #
      # @param _id [String] The unique identifier of the claim
      # @return [Hash] Single claim data transformed to ClaimResponse DTO format
      def get_claim(_id) = raise(NotImplementedError)
    end
  end
end
