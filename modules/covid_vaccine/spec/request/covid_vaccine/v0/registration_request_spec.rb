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

  let(:expected_response_attributes) do
    %w[first_name last_name birth_date zip_code zip_code_details phone email vaccine_interest created_at]
  end
  let(:summary_response_attributes) do
    %w[zip_code vaccine_interest created_at]
  end
  let(:profile) { build(:mpi_profile) }
  let(:mpi_profile_response) { create(:find_profile_response, profile:) }

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
        expect(CovidVaccine::V0::RegistrationSubmission).to receive(:create!)
          .and_raise(ActiveRecord::RecordInvalid.new(nil))
        post '/covid_vaccine/v0/registration', params: { registration: registration_attributes }
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
        post '/covid_vaccine/v0/registration', params: { registration: {} }
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
        post '/covid_vaccine/v0/registration', params: { registration: invalid_date_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'allows a non-existent date' do
        blank_date_attributes = registration_attributes.merge({ birth_date: '' })
        post '/covid_vaccine/v0/registration', params: { registration: blank_date_attributes }
        expect(response).to have_http_status(:created)
      end

      it 'returns a submission summary' do
        post '/covid_vaccine/v0/registration', params: { registration: registration_attributes }
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['data']['id']).to eq('')
        expect(body['data']['attributes']['created_at']).to be_truthy
      end

      it 'records the submission for processing' do
        expect { post '/covid_vaccine/v0/registration', params: { registration: registration_attributes } }
          .to change(CovidVaccine::V0::RegistrationSubmission, :count).by(1)
      end

      it 'kicks off the processing job' do
        expect { post '/covid_vaccine/v0/registration', params: { registration: registration_attributes } }
          .to change(CovidVaccine::SubmissionJob.jobs, :size).by(1)
      end
    end

    context 'with a loa1 user' do
      around do |example|
        VCR.use_cassette('covid_vaccine/vetext/post_vaccine_registry_loa1',
                         match_requests_on: %i[method path], &example)
      end

      before do
        sign_in_as(loa1_user)
      end

      it 'returns a submission_summary' do
        post '/covid_vaccine/v0/registration', params: { registration: registration_attributes }
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['data']['id']).to eq('')
        expect(body['data']['attributes']['created_at']).to be_truthy
      end

      it 'records the submission for processing' do
        expect { post '/covid_vaccine/v0/registration', params: { registration: registration_attributes } }
          .to change(CovidVaccine::V0::RegistrationSubmission, :count).by(1)
      end

      it 'kicks off the processing job' do
        expect { post '/covid_vaccine/v0/registration', params: { registration: registration_attributes } }
          .to change(CovidVaccine::SubmissionJob.jobs, :size).by(1)
      end
    end

    context 'with a loa3 user' do
      around do |example|
        VCR.use_cassette('covid_vaccine/vetext/post_vaccine_registry_loa3',
                         match_requests_on: %i[method path], &example)
      end

      before do
        sign_in_as(loa3_user)
      end

      it 'returns a submission_summary' do
        post '/covid_vaccine/v0/registration', params: { registration: registration_attributes }
        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body['data']['id']).to eq('')
        expect(body['data']['attributes']['created_at']).to be_truthy
      end

      it 'records the submission for processing' do
        expect { post '/covid_vaccine/v0/registration', params: { registration: registration_attributes } }
          .to change(CovidVaccine::V0::RegistrationSubmission, :count).by(1)
      end

      it 'kicks off the processing job' do
        expect { post '/covid_vaccine/v0/registration', params: { registration: registration_attributes } }
          .to change(CovidVaccine::SubmissionJob.jobs, :size).by(1)
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

      context 'before submission is processed' do
        let!(:submission) do
          create(:covid_vax_registration, :unsubmitted,
                 account_id: loa3_user.account_uuid)
        end

        it 'returns the submission record' do
          get '/covid_vaccine/v0/registration'
          expect(response).to have_http_status(:ok)
        end

        it 'returns an empty submission id' do
          get '/covid_vaccine/v0/registration'
          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body['data']['id']).to eq ''
        end

        it 'returns submitted traits' do
          get '/covid_vaccine/v0/registration'
          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body['data']['attributes']).to include(*expected_response_attributes)
        end
      end

      context 'with a previous submission' do
        let!(:submission) do
          create(:covid_vax_registration,
                 account_id: loa3_user.account_uuid)
        end

        it 'returns the submission record' do
          get '/covid_vaccine/v0/registration'
          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body['data']['id']).to eq(submission.sid)
          expect(body['data']['attributes']).to include(*expected_response_attributes)
          expect(body['data']['attributes']).to include('first_name' => 'Jon',
                                                        'last_name' => 'Doe')
        end

        it 'omits any sensitive fields' do
          get '/covid_vaccine/v0/registration'
          body = JSON.parse(response.body)
          expect(body['data']['attributes']).not_to include('ssn', 'patient_ssn')
          expect(body['data']['attributes']).not_to include('icn', 'patient_icn')
        end
      end

      context 'with a submission where traits get altered' do
        let!(:submission) do
          create(:covid_vax_registration, :from_loa3,
                 account_id: loa3_user.account_uuid)
        end

        it 'returns the originally submitted data' do
          get '/covid_vaccine/v0/registration'
          body = JSON.parse(response.body)
          expect(body['data']['attributes']['first_name']).to eq(submission.raw_form_data['first_name'])
          expect(body['data']['attributes']['first_name']).not_to eq(submission.form_data['first_name'])
        end
      end

      context 'with multiple submissions' do
        let!(:submission1) do
          create(:covid_vax_registration,
                 account_id: loa3_user.account_uuid,
                 created_at: Time.zone.now - 2.minutes)
        end
        let!(:submission2) do
          create(:covid_vax_registration,
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

      context 'opting out of submission' do
        before do
          sign_in_as(loa3_user)
        end

        it 'opts email out' do
          Sidekiq::Testing.inline! do
            VCR.use_cassette('covid_vaccine/vetext/create_and_opt_out', match_requests_on: %i[method path]) do
              post '/covid_vaccine/v0/registration', params: { registration: registration_attributes }
              get '/covid_vaccine/v0/registration'
              body = JSON.parse(response.body)
              sid = body['data']['id']
              put "/covid_vaccine/v0/registration/opt_out?sid=#{sid}"
              expect(response).to have_http_status(:no_content)
            end
          end
        end
      end

      context 'opting in on previously opted out submission' do
        before do
          sign_in_as(loa3_user)
        end

        it 'opts email in' do
          Sidekiq::Testing.inline! do
            VCR.use_cassette('covid_vaccine/vetext/create_and_opt_in', match_requests_on: %i[method path]) do
              post '/covid_vaccine/v0/registration', params: { registration: registration_attributes }
              get '/covid_vaccine/v0/registration'
              body = JSON.parse(response.body)
              sid = body['data']['id']
              put "/covid_vaccine/v0/registration/opt_in?sid=#{sid}"
              expect(response).to have_http_status(:no_content)
            end
          end
        end
      end
    end
  end
end
