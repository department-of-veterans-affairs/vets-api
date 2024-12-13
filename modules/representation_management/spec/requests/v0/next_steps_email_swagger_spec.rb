# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require_relative '../../support/swagger_shared_components/v0'

RSpec.describe 'Next Steps Email', openapi_spec: 'modules/representation_management/app/swagger/v0/swagger.json',
                                   type: :request do
  before do
    create(:accredited_organization,
           id: SwaggerSharedComponents::V0.representative[:organization_id],
           name: 'Veterans Organization')
    create(:accredited_individual,
           id: SwaggerSharedComponents::V0.representative[:id])
  end

  path '/representation_management/v0/next_steps_email' do
    post('Enqueue the Next Steps Email from VA Notify') do
      tags 'Next Steps Email'
      consumes 'application/json'
      produces 'application/json'
      operationId 'nextStepsEmail'

      parameter SwaggerSharedComponents::V0.body_examples[:next_steps_email_parameter]

      response '200', 'Email enqueued' do
        let(:next_steps_email) do
          SwaggerSharedComponents::V0.body_examples[:next_steps_email]
        end
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Email enqueued' }
               }

        run_test!
      end

      response '422', 'unprocessable entity response' do
        let(:next_steps_email) do
          params = SwaggerSharedComponents::V0.body_examples[:next_steps_email]
          params.delete(:email_address)
          params
        end
        schema '$ref' => '#/components/schemas/errors'
        run_test!
      end
    end
  end
end
