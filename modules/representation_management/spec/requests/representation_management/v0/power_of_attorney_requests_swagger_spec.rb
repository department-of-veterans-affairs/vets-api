# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require_relative '../../../support/swagger_shared_components/v0'

RSpec.describe 'Power of Attorney Requests',
               openapi_spec: 'modules/representation_management/app/swagger/v0/swagger.json',
               type: :request do
  let(:user) { create(:user, :loa3) }
  let!(:organization) do
    create(:organization, poa: SwaggerSharedComponents::V0.poa_request_representative[:organization_id],
                          can_accept_digital_poa_requests: true)
  end
  let!(:representative) do
    create(:representative, representative_id: SwaggerSharedComponents::V0.poa_request_representative[:id])
  end

  path '/representation_management/v0/power_of_attorney_requests' do
    post('Submit a Power of Attorney Request (Form 21-22)') do
      tags 'Power of Attorney Requests'
      consumes 'application/json'
      operationId 'createPOARequest'
      produces 'application/json'
      parameter SwaggerSharedComponents::V0.body_examples[:poa_request_parameter]

      describe 'Successful submission' do
        response '201', 'POA Request Submitted Successfully' do
          let(:poa_request) do
            SwaggerSharedComponents::V0.body_examples[:poa_request]
          end

          let(:poa_request_result) do
            OpenStruct.new(id: 'efd18b43-4421-4539-941a-7397fadfe5dc',
                           created_at: '2025-02-21T00:00:00.000000000Z'.to_datetime,
                           expires_at: '2025-04-22T00:00:00.000000000Z'.to_datetime)
          end
          before do
            sign_in_as(user)
            Flipper.enable(:appoint_a_representative_enable_v2_features) # rubocop:disable Project/ForbidFlipperToggleInSpecs
            allow_any_instance_of(RepresentationManagement::PowerOfAttorneyRequestService::Orchestrate)
              .to receive(:call)
              .and_return({ request: poa_request_result })
          end

          schema '$ref' => '#/components/schemas/poaRequest'
          run_test!
        end
      end

      describe 'Getting a 422 response' do
        response '422', 'unprocessable entity response' do
          produces 'application/json'
          let(:poa_request) do
            params = SwaggerSharedComponents::V0.body_examples[:poa_request]
            params[:veteran][:name].delete(:first)
            params
          end

          before do
            sign_in_as(user)
            Flipper.enable(:appoint_a_representative_enable_v2_features) # rubocop:disable Project/ForbidFlipperToggleInSpecs
          end

          schema '$ref' => '#/components/schemas/errors'
          run_test!
        end
      end
    end
  end
end
