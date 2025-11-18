# frozen_string_literal: true

# Interface for a BenefitsClaimsProvider
#
# Include this module in a new ClaimsProvider class to define a standardized interface
#   for fetching benefits claims data from various sources.

# The new class MUST implement these methods to be a valid BenefitsClaimsProvider:
#
# TODO:Create a standardized claim response structure that represents what VA.gov expects (i.e. `lib/benefits_claims/responses/claim_response.rb`)
# @see lib/benefits_claims/responses/claim_response.rb for the expected response structure (not yet created)
# @see lib/claim_letters/providers/claim_letters/claim_letters_provider.rb for reference implementation
#
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
