# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CovidVaccine::V0::ExpandedRegistration', type: :request do
  include SchemaMatchers

  let(:registration_attributes) do
    {
      applicant_type: 'veteran',
      first_name: 'Jane',
      last_name: 'Doe',
      birth_date: '1952-02-02',
      phone: '555-555-1234',
      email_address: 'jane.doe@email.com',
      ssn: '000000022',
      address_line1: '123 Fake Street',
      city: 'Springfield',
      state_code: 'CA',
      zip_code: '94402'
    }
  end

  let(:response_attributes) do
    %w[created_at]
  end

  describe 'registration#create' do
    context 'feature disabled' do
      around do |example|
        Flipper.disable(:covid_vaccine_registration_expanded)
        example.run
        Flipper.enable(:covid_vaccine_registration_expanded)
      end

      it 'returns a 404 route not found' do
        post '/covid_vaccine/v0/expanded_registration', params: { registration: registration_attributes }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when encountering an Internal Server Error' do
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
                'title' => "First name can't be blank",
                'detail' => "first-name - can't be blank",
                'code' => '100',
                'source' => {
                  'pointer' => 'data/attributes/first-name'
                },
                'status' => '422'
              },
              {
                'title' => "Last name can't be blank",
                'detail' => "last-name - can't be blank",
                'code' => '100',
                'source' => {
                  'pointer' => 'data/attributes/last-name'
                },
                'status' => '422'
              },
              {
                'title' => 'Ssn should be in the form 123121234',
                'detail' => 'ssn - should be in the form 123121234',
                'code' => '100',
                'source' => {
                  'pointer' => 'data/attributes/ssn'
                },
                'status' => '422'
              },
              {
                'title' => 'Birth date should be in the form yyyy-mm-dd',
                'detail' => 'birth-date - should be in the form yyyy-mm-dd',
                'code' => '100',
                'source' => {
                  'pointer' => 'data/attributes/birth-date'
                },
                'status' => '422'
              },
              {
                'title' => "Address line1 can't be blank",
                'detail' => "address-line1 - can't be blank",
                'code' => '100',
                'source' => {
                  'pointer' => 'data/attributes/address-line1'
                },
                'status' => '422'
              },
              {
                'title' => "City can't be blank",
                'detail' => "city - can't be blank",
                'code' => '100',
                'source' => {
                  'pointer' => 'data/attributes/city'
                },
                'status' => '422'
              },
              {
                'title' => "State code can't be blank",
                'detail' => "state-code - can't be blank",
                'code' => '100',
                'source' => {
                  'pointer' => 'data/attributes/state-code'
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

      it 'logs an audit record with appropriate applicant type' do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with('Covid_Vaccine Expanded_Submission',
                                                    /"applicant_type":"veteran"/)
        post '/covid_vaccine/v0/expanded_registration', params: { registration: registration_attributes }
      end
    end

    context 'when a submission does not include an email' do
      let(:registration_attributes) do
        build(:covid_vax_expanded_registration, :blank_email).raw_form_data.symbolize_keys
      end

      it 'accepts the submission' do
        post '/covid_vaccine/v0/expanded_registration', params: { registration: registration_attributes }
        expect(response).to have_http_status(:created)
      end

      it 'records the submission for processing' do
        expect { post '/covid_vaccine/v0/expanded_registration', params: { registration: registration_attributes } }
          .to change(CovidVaccine::V0::ExpandedRegistrationSubmission, :count).by(1)
      end

      it 'logs an audit record with has_email false' do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with('Covid_Vaccine Expanded_Submission',
                                                    /"has_email":false/)
        post '/covid_vaccine/v0/expanded_registration', params: { registration: registration_attributes }
      end

      it 'does not kick off a CovidVaccine::ExpandedRegistrationEmailJob' do
        expect(CovidVaccine::ExpandedRegistrationEmailJob).not_to receive(:perform_async)
        post '/covid_vaccine/v0/expanded_registration', params: { registration: registration_attributes }
      end
    end

    context 'with a spouse submission' do
      let(:registration_attributes) do
        build(:covid_vax_expanded_registration, :spouse).raw_form_data.symbolize_keys
      end

      it 'accepts the submission' do
        post '/covid_vaccine/v0/expanded_registration', params: { registration: registration_attributes }
        expect(response).to have_http_status(:created)
      end

      it 'records the submission for processing' do
        expect { post '/covid_vaccine/v0/expanded_registration', params: { registration: registration_attributes } }
          .to change(CovidVaccine::V0::ExpandedRegistrationSubmission, :count).by(1)
      end

      it 'logs an audit record with appropriate applicant type' do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with('Covid_Vaccine Expanded_Submission',
                                                    /"applicant_type":"spouse"/)
        post '/covid_vaccine/v0/expanded_registration', params: { registration: registration_attributes }
      end
    end

    context 'with non-US submissions' do
      it 'accepts a Canada address' do
        attrs = build(:covid_vax_expanded_registration, :canada).raw_form_data.symbolize_keys
        post '/covid_vaccine/v0/expanded_registration', params: { registration: attrs }
        expect(response).to have_http_status(:created)
      end

      it 'accepts a Mexico address' do
        attrs = build(:covid_vax_expanded_registration, :mexico).raw_form_data.symbolize_keys
        post '/covid_vaccine/v0/expanded_registration', params: { registration: attrs }
        expect(response).to have_http_status(:created)
      end

      it 'accepts a Phillipines address' do
        attrs = build(:covid_vax_expanded_registration, :non_us).raw_form_data.symbolize_keys
        post '/covid_vaccine/v0/expanded_registration', params: { registration: attrs }
        expect(response).to have_http_status(:created)
      end
    end

    it 'accepts submission with a nil country' do
      attrs = build(:covid_vax_expanded_registration,
                    raw_options: { 'country_name' => nil }).raw_form_data.symbolize_keys
      post '/covid_vaccine/v0/expanded_registration', params: { registration: attrs }
      expect(response).to have_http_status(:created)
    end
  end
end
