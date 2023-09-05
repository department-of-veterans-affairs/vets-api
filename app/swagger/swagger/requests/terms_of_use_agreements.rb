# frozen_string_literal: true

module Swagger
  module Requests
    class TermsOfUseAgreements
      include Swagger::Blocks

      swagger_path '/v0/terms_of_use_agreements/{version}/accept' do
        operation :post do
          key :description, 'Accepts the terms of use agreement'
          key :operationId, 'acceptTermsOfUseAgreement'
          key :tags, [
            'terms_of_use_agreements'
          ]

          parameter do
            key :name, :version
            key :in, :path
            key :description, 'Version of the terms of use agreement'
            key :required, true
            key :type, :string
          end

          response 201 do
            key :description, 'accept terms of use agreement response'
            schema do
              key :$ref, :TermsOfUseAgreement
            end
          end

          response 422 do
            key :description, 'unprocessable entity response'
            schema do
              key :$ref, :Errors
            end
          end
        end
      end

      swagger_path '/v0/terms_of_use_agreements/{version}/decline' do
        operation :post do
          key :description, 'Declines the terms of use agreement'
          key :operationId, 'declineTermsOfUseAgreement'
          key :tags, [
            'terms_of_use_agreements'
          ]

          parameter do
            key :name, :version
            key :in, :path
            key :description, 'Version of the terms of use agreement'
            key :required, true
            key :type, :string
          end

          response 201 do
            key :description, 'decline terms of use agreement response'
            schema do
              key :$ref, :TermsOfUseAgreement
            end
          end

          response 422 do
            key :description, 'unprocessable entity response'
            schema do
              key :$ref, :Errors
            end
          end
        end
      end
    end
  end
end
