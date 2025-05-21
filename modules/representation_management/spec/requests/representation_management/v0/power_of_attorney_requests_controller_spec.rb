# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentationManagement::V0::PowerOfAttorneyRequests', type: :request do
  describe 'POST #create' do
    let(:user) { create(:user, :loa3) }
    let!(:user_verification) { create(:idme_user_verification, idme_uuid: user.idme_uuid) }
    let(:base_path) { '/representation_management/v0/power_of_attorney_requests' }
    let(:organization) { create(:organization, can_accept_digital_poa_requests: accepts_digital_requests) }
    let(:accepts_digital_requests) { true }
    let(:representative) { create(:representative) }
    let(:params) do
      {
        power_of_attorney_request: {
          record_consent: true,
          consent_address_change: true,
          consent_limits: [],
          veteran: {
            ssn: '123456789',
            va_file_number: '123456789',
            date_of_birth: '1980-12-31',
            service_number: 'AA12345',
            service_branch: 'ARMY',
            phone: '5555555555',
            email: 'veteran@example.com',
            name: {
              first: 'John',
              middle: 'Middle',
              last: 'Veteran'
            },
            address: {
              address_line1: '123 Fake Veteran St',
              address_line2: '',
              city: 'Portland',
              state_code: 'OR',
              country: 'USA',
              zip_code: '12345',
              zip_code_suffix: '6789'
            }
          },
          representative: {
            organization_id: organization.poa,
            id: representative.representative_id
          }
        }
      }
    end

    context 'when appoint_a_representative_enable_v2_features is enabled' do
      context 'with a signed in user' do
        before do
          sign_in_as(user)
          allow(Flipper).to receive(:enabled?).with(:appoint_a_representative_enable_v2_features).and_return(true)
        end

        context 'When submitting all fields with valid data' do
          let(:poa_request) do
            OpenStruct.new(id: 'efd18b43-4421-4539-941a-7397fadfe5dc',
                           created_at: '2025-02-21T00:00:00.000000000Z'.to_datetime,
                           expires_at: '2025-04-22T00:00:00.000000000Z'.to_datetime)
          end

          before do
            allow_any_instance_of(RepresentationManagement::PowerOfAttorneyRequestService::Orchestrate)
              .to receive(:call)
              .and_return({ request: poa_request })
          end

          it 'responds with a 201/created status' do
            post(base_path, params:)

            expect(response).to have_http_status(:created)
          end

          it 'responds with the newly created PowerOfAttorneyRequest' do
            post(base_path, params:)

            parsed_response = JSON.parse(response.body)

            expect(parsed_response['data']['id']).to eq(poa_request.id)
          end
        end

        context 'when form validation fails' do
          before do
            params[:power_of_attorney_request][:veteran][:name][:first] = nil
            post(base_path, params:)
          end

          it 'responds with a 422/unprocessable_entity status' do
            expect(response).to have_http_status(:unprocessable_entity)
          end

          it 'responds with an error message specifying the failed validation(s)' do
            expect(response.body).to eq({ errors: ["Veteran first name can't be blank"] }.to_json)
          end
        end
      end
    end

    context 'without a signed in user' do
      it 'returns a 401/unauthorized status' do
        post(base_path, params:)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when appoint_a_representative_enable_v2_features is disabled' do
      before do
        sign_in_as(user)
        allow(Flipper).to receive(:enabled?).with(:appoint_a_representative_enable_v2_features).and_return(false)
      end

      it 'returns a 404/not_found status' do
        post(base_path, params:)

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
