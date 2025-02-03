# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentationManagement::V0::PowerOfAttorneyRequestsController', type: :request do
  describe 'POST #create' do
    let(:user) { create(:user, :loa3) }
    let(:base_path) { '/representation_management/v0/power_of_attorney_requests' }
    let(:organization) { create(:organization) } # This is the legacy organization
    let(:representative) { create(:representative) } # This is the legacy representative
    let(:params) do
      {
        power_of_attorney_request: {
          record_consent: '',
          consent_address_change: '',
          consent_limits: [],
          claimant: {
            date_of_birth: '1980-12-31',
            relationship: 'Spouse',
            phone: '5555555555',
            email: 'claimant@example.com',
            name: {
              first: 'John',
              middle: 'Middle', # This is a middle name as submitted by the frontend
              last: 'Claimant'
            },
            address: {
              address_line1: '123 Fake Claimant St',
              address_line2: '',
              city: 'Portland',
              state_code: 'OR',
              country: 'USA', # This is a 3 character country code as submitted by the frontend
              zip_code: '12345',
              zip_code_suffix: '6789'
            }
          },
          veteran: {
            ssn: '123456789',
            va_file_number: '123456789',
            date_of_birth: '1980-12-31',
            service_number: '123456789',
            service_branch: 'ARMY',
            phone: '5555555555',
            email: 'veteran@example.com',
            name: {
              first: 'John',
              middle: 'Middle', # This is a middle name as submitted by the frontend
              last: 'Veteran'
            },
            address: {
              address_line1: '123 Fake Veteran St',
              address_line2: '',
              city: 'Portland',
              state_code: 'OR',
              country: 'USA', # This is a 3 character country code as submitted by the frontend
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

    context 'with a signed in user' do
      before do
        sign_in_as(user)
      end

      context 'When submitting all fields with valid data' do
        before do
          params[:power_of_attorney_request][:veteran][:service_number] = nil # TEMPORARY FOR FRONTEND TESTING
          post(base_path, params:)
        end

        it 'responds with a ok status' do
          expect(response).to have_http_status(:ok)
        end

        it 'responds with the expected message' do
          expect(response.body).to eq({ message: 'Email enqueued' }.to_json)
        end
      end

      context 'when submitting with a veteran service number - TEMPORARY FOR FRONTEND TESTING' do
        before do
          post(base_path, params: params)
        end

        it 'responds with the unprocessable_entity status' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          expect(response.body).to eq({ errors: ['render_error_state_for_failed_submission'] }.to_json)
        end
      end

      context 'when submitting without the veteran first name for a single validation error' do
        before do
          params[:power_of_attorney_request][:veteran][:service_number] = nil # TEMPORARY FOR FRONTEND TESTING
          params[:power_of_attorney_request][:veteran][:name][:first] = nil
          post(base_path, params:)
        end

        it 'responds with an unprocessable entity status' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          expect(response.body).to eq({ errors: ["Veteran first name can't be blank"] }.to_json)
        end
      end
    end

    context 'without a signed in user' do
      it 'returns a 401/unauthorized status' do
        post(base_path, params:)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
