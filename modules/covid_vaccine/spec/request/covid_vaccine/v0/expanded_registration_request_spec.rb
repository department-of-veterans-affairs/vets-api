# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Covid Vaccine Expanded Registration', type: :request do
  include SchemaMatchers

  let(:registration_attributes) do
    {
      vaccine_interest: 'yes',
      authenticated: true,
      first_name: 'Jane',
      last_name: 'Doe',
      birth_date: '1952-02-02',
      phone: '555-555-1234',
      email: 'jane.doe@email.com',
      ssn: '000-00-0022',
      zip_code: '94402',
      zip_code_details: 'yes'
    }
  end

  let(:response_attributes) do
    %w[created_at]
  end

  describe 'registration#create' do
    context 'feature disabled' do
      around do |example|
        Flipper.disable(:covid_vaccine_registration)
        example.run
        Flipper.enable(:covid_vaccine_registration)
      end

      it 'returns a 404 route not found' do
        post '/covid_vaccine/v0/expanded_registration', params: { registration: registration_attributes }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when encountering an Internal Server Error' do
      let(:registration_attributes) do
        {
          vaccine_interest: 'yes',
          email: 'jane.doe@email.com',
          zip_code: '94402',
          date_vaccine_reeceived: ''
        }
      end

      it 'raises a BackendServiceException' do
        expect(CovidVaccine::V0::ExpandedRegistrationSubmission).to receive(:create!)
          .and_raise(ActiveRecord::RecordInvalid.new(nil))
        post '/covid_vaccine/v0/expanded_registration', params: { registration: registration_attributes }
        expect(response).to have_http_status(:internal_server_error)
        # TODO: Add more thorough expectation
      end
    end

    context 'with an unauthenticated user' do
      around do |example|
        VCR.use_cassette('covid_vaccine/vetext/post_vaccine_registry_unauth',
                         match_requests_on: %i[method path], &example)
      end

      it 'returns errors if form validation fails' do
        post '/covid_vaccine/v0/expanded_registration', params: { registration: {} }
        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body).to eq(
          {
            'errors' => [
              {
                'title' => 'Email is invalid',
                'detail' => 'email - is invalid',
                'code' => '100',
                'source' => {
                  'pointer' => 'data/attributes/email'
                },
                'status' => '422'
              },
              {
                'title' => "Vaccine interest can't be blank",
                'detail' => "vaccine-interest - can't be blank",
                'code' => '100',
                'source' => {
                  'pointer' => 'data/attributes/vaccine-interest'
                },
                'status' => '422'
              },
              {
                'title' => 'Zip code should be in the form 12345 or 12345-1234',
                'detail' => 'zip-code - should be in the form 12345 or 12345-1234',
                'code' => '100',
                'source' => {
                  'pointer' => 'data/attributes/zip-code'
                },
                'status' => '422'
              }
            ]
          }
        )
      end

      it 'returns an error on a malformed date' do
        invalid_date_attributes = registration_attributes.merge({ birth_date: '2000-01-XX' })
        post '/covid_vaccine/v0/expanded_registration', params: { registration: invalid_date_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'allows a non-existent date' do
        blank_date_attributes = registration_attributes.merge({ birth_date: '' })
        post '/covid_vaccine/v0/expanded_registration', params: { registration: blank_date_attributes }
        expect(response).to have_http_status(:created)
      end

      it 'returns a submission summary' do
        post '/covid_vaccine/v0/expanded_registration', params: { registration: registration_attributes }

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['data']['id']).to eq('')
        expect(body['data']['attributes']['created_at']).to be_truthy
      end

      it 'records the submission for processing' do
        expect { post '/covid_vaccine/v0/expanded_registration', params: { registration: registration_attributes } }
          .to change(CovidVaccine::V0::ExpandedRegistrationSubmission, :count).by(1)
      end

      it 'kicks off the email confirmation job' do
        expect { post '/covid_vaccine/v0/expanded_registration', params: { registration: registration_attributes } }
          .to change(CovidVaccine::ExpandedRegistrationEmailJob.jobs, :size).by(1)
      end
    end
  end
end
