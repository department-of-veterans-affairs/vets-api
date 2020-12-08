# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Covid Vaccine Registration', type: :request do
  include SchemaMatchers

  let(:loa1_user) { build(:user, :vaos, :loa1) }
  let(:loa3_user) { build(:user, :vaos) }

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
        post "/covid_vaccine/v0/registration", params: { registration: registration_attributes }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with an unauthenticated user' do
    end

    context 'with a loa1 user' do
    end

    context 'with a loa3 user' do
    end
  end

  describe 'registration#show' do
    context 'with an unauthenticated user' do
      it 'returns a 403 Unauthorized' do
        get "/covid_vaccine/v0/registration"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a loa1 user' do
      before do
        sign_in_as(loa1_user)
      end

      it 'returns a 403 Unauthorized' do
        get "/covid_vaccine/v0/registration"
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
          get "/covid_vaccine/v0/registration"
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'feature enabled but no record found' do
        it 'returns a 404 record not found ' do
          get "/covid_vaccine/v0/registration"
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'feature enabled and one record exists' do
        xit 'returns the record' do
          get "/covid_vaccine/v0/registration"
          expect(response).to have_http_status(:success)
        end
      end

      context 'feature enabled and multiple records exists' do
        xit 'returns the last created record' do
          get "/covid_vaccine/v0/registration"
          expect(response).to have_http_status(:success)
        end
      end
    end
  end
end
