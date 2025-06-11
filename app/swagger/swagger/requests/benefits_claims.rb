# frozen_string_literal: true

module Swagger
  module Requests
    class BenefitsClaims
      include Swagger::Blocks

      swagger_path '/v0/benefits_claims/{id}' do
        operation :get do
          key :description, 'Retrieve more information about a Claim via Lighthouse::BenefitsClaims::Service'
          key :operationId, 'benefitsClaim'
          key :tags, %w[benefits_claims]

          parameter do
            key :name, :id
            key :description, 'Lighthouse ID for the Benefit Claim'
            key :in, :path
            key :required, true
            key :type, :integer
          end

          response 200 do
            key :description, 'Response is OK'
          end
        end
      end
    end
  end
end
