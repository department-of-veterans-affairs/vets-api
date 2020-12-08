# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Covid Vaccine Registration', type: :request do
  include SchemaMatchers

  let(:loa1_user) { build(:user, :vaos, :loa1) }
  let(:loa3_user) { build(:user, :vaos, :accountable) }

  let(:registration_attributes) do
    {
      vaccine_interest: 'yes',
      authenticated: true,
      date_vaccine_reeceived: '',
      contact: true,
      contact_method: 'phone',
      reason_undecided: '',
      first_name: 'Jane',
      last_name: 'Doe',
      date_of_birth: '2/2/1952',
      phone: '555-555-1234',
      email: 'jane.doe@email.com',
      patient_ssn: '000-00-0022'
    }
  end

  describe 'registration#create' do
    context 'feature disabled' do
      around do |example|
        Flipper.disable(:covid_vaccine_registration)
        example.run
        Flipper.enable(:covid_vaccine_registration)
      end

      it 'returns a 404 route not found' do
        post '/covid_vaccine/v0/registration', params: { registration: registration_attributes }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with an unauthenticated user' do
      it 'returns a sid' do
        VCR.use_cassette('covid_vaccine/vetext/put_vaccine_registry_200', match_requests_on: %i[method uri]) do
          post '/covid_vaccine/v0/registration', params: { registration: registration_attributes }
        end
      end
    end

    context 'with a loa1 user' do
      before do
        sign_in_as(loa1_user)
      end

      it 'returns a sid' do
        VCR.use_cassette('covid_vaccine/vetext/put_vaccine_registry_200', match_requests_on: %i[method uri]) do
          post '/covid_vaccine/v0/registration', params: { registration: registration_attributes }
        end
      end
    end

    context 'with a loa3 user' do
      before do
        sign_in_as(loa3_user)
      end

      it 'returns a sid' do
        VCR.use_cassette('covid_vaccine/vetext/put_vaccine_registry_200', match_requests_on: %i[method uri]) do
          post '/covid_vaccine/v0/registration', params: { registration: registration_attributes }
        end
      end
    end
  end

  describe 'registration#show' do
    context 'with an unauthenticated user' do
      it 'returns a 403 Unauthorized' do
        get '/covid_vaccine/v0/registration'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a loa1 user' do
      before do
        sign_in_as(loa1_user)
      end

      it 'returns a 403 Unauthorized' do
        get '/covid_vaccine/v0/registration'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a loa3 user' do
      before do
        sign_in_as(loa3_user)
      end

      context 'feature disabled' do
        around do |example|
          Flipper.disable(:covid_vaccine_registration)
          example.run
          Flipper.enable(:covid_vaccine_registration)
        end

        it 'returns a 404 route not found' do
          get '/covid_vaccine/v0/registration'
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'with no previous submission' do
        it 'renders not found' do
          get '/covid_vaccine/v0/registration'
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'with a previous submission' do
        let!(:submission) do
          create(:covid_vaccine_registration_submission,
                 account_id: loa3_user.account_uuid)
        end

        it 'returns the submission record' do
          get '/covid_vaccine/v0/registration'
          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body['data']['id']).to eq(submission.sid)
        end
      end

      context 'with multiple submissions' do
        let!(:submission1) do
          create(:covid_vaccine_registration_submission,
                 account_id: loa3_user.account_uuid,
                 created_at: Time.zone.now - 2.minutes)
        end
        let!(:submission2) do
          create(:covid_vaccine_registration_submission,
                 account_id: loa3_user.account_uuid,
                 created_at: Time.zone.now - 1.minute)
        end

        it 'returns the latest one' do
          get '/covid_vaccine/v0/registration'
          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body['data']['id']).to eq(submission2.sid)
        end
      end
    end
  end
end
