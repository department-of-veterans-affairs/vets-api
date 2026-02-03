# frozen_string_literal: true

require 'benefits_claims/providers/benefits_claims/benefits_claims_provider'
require 'benefits_claims/responses/claim_response'
require 'benefits_claims/providers/lighthouse/claim_builder'
require 'benefits_claims/providers/lighthouse/claim_serializer'
require 'lighthouse/benefits_claims/service'
require 'lighthouse/benefits_claims/configuration'
require 'lighthouse/service_exception'

module BenefitsClaims
  module Providers
    module Lighthouse
      # Provider implementation for Lighthouse Benefits Claims API
      #
      # Wraps the existing BenefitsClaims::Service and transforms Lighthouse API
      # responses through the ClaimResponse DTO to ensure data consistency and validation.
      #
      # While Lighthouse already returns data in JSON:API format with camelCase attributes,
      # this transformation layer demonstrates the provider pattern for future implementations
      # (e.g., CHAMPVA) that will need to transform their native formats.
      #
      # @example Usage
      #   provider = LighthouseBenefitsClaimsProvider.new(user)
      #   claims = provider.get_claims # Returns transformed claim data
      #   claim = provider.get_claim('123') # Returns transformed single claim
      class LighthouseBenefitsClaimsProvider
        include BenefitsClaims::Providers::BenefitsClaimsProvider

        def initialize(user)
          @user = user
          @service = BenefitsClaims::Service.new(user)
          @config = BenefitsClaims::Configuration.instance
        end

        def get_claims
          response = @service.get_claims

          # Transform each claim through the DTO and add provider metadata
          response['data'] = response['data'].map do |claim_data|
            claim_data['provider'] = 'lighthouse'
            transform_to_dto(claim_data)
          end

          response
        rescue Faraday::ClientError, Faraday::ServerError => e
          handle_error(e, 'claims')
        end

        def get_claim(id)
          response = @service.get_claim(id)

          # Transform the single claim through the DTO and add provider metadata
          response['data']['provider'] = 'lighthouse'
          response['data'] = transform_to_dto(response['data'])

          response
        rescue Faraday::ClientError, Faraday::ServerError => e
          handle_error(e, "claims/#{id}")
        end

        private

        # Transforms Lighthouse claim data through ClaimResponse DTO
        #
        # This method demonstrates the transformation pattern that future providers
        # will need to implement. For Lighthouse, this validates the data structure
        # and ensures consistency.
        def transform_to_dto(claim_data)
          dto = ClaimBuilder.build_claim_response(claim_data)
          ClaimSerializer.to_json_api(dto)
        end

        def handle_error(error, endpoint)
          ::Lighthouse::ServiceException.send_error(
            error,
            self.class.to_s.underscore,
            nil,
            "#{@config.base_api_path}/#{endpoint}"
          )
        end
      end
    end
  end
end
