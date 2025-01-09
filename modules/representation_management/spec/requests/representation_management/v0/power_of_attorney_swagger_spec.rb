# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s

RSpec.describe 'Power of Attorney API', openapi_spec: 'modules/representation_management/app/swagger/v0/swagger.json',
                                        type: :request do
  let(:user) { create(:user, :loa3) }

  # rubocop:disable RSpec/ScatteredSetup
  path '/representation_management/v0/power_of_attorney' do
    before do
      sign_in_as(user)
    end

    get('Get Power of Attorney') do
      tags 'Power of Attorney'
      description 'Retrieves the Power of Attorney for a veteran, if any.'
      operationId 'getPowerOfAttorney'

      produces 'application/json'

      response '200',
               'Successfully checked for Power of Attorney information' do
        before do
          lh_response = {
            'data' => {
              'type' => 'individual',
              'attributes' => {
                'code' => 'abc'
              }
            }
          }
          allow_any_instance_of(BenefitsClaims::Service).to receive(:get_power_of_attorney).and_return(lh_response)
        end

        schema anyOf: [
          {
            '$ref' => '#/components/schemas/powerOfAttorneyResponse'
          },
          {
            type: :object,
            description: 'An empty JSON object indicating no Power of Attorney exists.',
            example: {}
          }
        ]

        run_test!
      end

      response '422', 'Unprocessable Entity' do
        before do
          allow_any_instance_of(BenefitsClaims::Service)
            .to receive(:get_power_of_attorney)
            .and_raise(Common::Exceptions::UnprocessableEntity)
        end

        schema '$ref' => '#/components/schemas/errorModel'

        run_test!
      end

      response '500', 'Internal Server Error' do
        schema '$ref' => '#/components/schemas/errorModel'
        run_test!
      end
    end
  end
  # rubocop:enable RSpec/ScatteredSetup
end
