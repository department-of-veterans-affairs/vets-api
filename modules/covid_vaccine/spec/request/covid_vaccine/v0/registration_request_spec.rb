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
      birth_date: '2/2/1952',
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
  let(:mvi_profile) { build(:mvi_profile) }
  let(:mvi_profile_response) do
    MPI::Responses::FindProfileResponse.new(
      status: MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
      profile: mvi_profile
    )
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

    context 'with an invalid attribute in request' do
      let(:registration_attributes) { { date_vaccine_reeceived: '' } }

      it 'raises a BackendServiceException' do
        VCR.use_cassette('covid_vaccine/vetext/post_vaccine_registry_400', match_requests_on: %i[method path]) do
          post '/covid_vaccine/v0/registration', params: { registration: registration_attributes }
          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['errors'].first).to eq(
            {
              'title' => 'Bad Request',
              'detail' => 'Unrecognized field dateVaccineReeceived',
              'code' => 'VETEXT_400',
              'source' => 'POST: /api/vetext/pub/covid/vaccine/registry',
              'status' => '400'
            }
          )
        end
      end
    end

    context 'when encountering an Internal Server Error' do
      let(:registration_attributes) { { date_vaccine_reeceived: '' } }

      it 'raises a BackendServiceException' do
        VCR.use_cassette('covid_vaccine/vetext/post_vaccine_registry_500', match_requests_on: %i[method path]) do
          post '/covid_vaccine/v0/registration', params: { registration: registration_attributes }
          expect(response).to have_http_status(:bad_gateway)
          expect(JSON.parse(response.body)['errors'].first).to eq(
            {
              'title' => 'Bad Gateway',
              'detail' => 'All your base are belong to us!!',
              'code' => 'VETEXT_502',
              'source' => 'POST: /api/vetext/pub/covid/vaccine/registry',
              'status' => '502'
            }
          )
        end
      end
    end

    context 'with an unauthenticated user' do
      it 'returns a sid' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)
        VCR.use_cassette('covid_vaccine/vetext/post_vaccine_registry_unauth', match_requests_on: %i[method path]) do
          expect { post '/covid_vaccine/v0/registration', params: { registration: registration_attributes } }
            .to change(CovidVaccine::SubmissionJob.jobs, :size).by(1)
            .and change(CovidVaccine::V0::RegistrationSubmission, :count).by(1)
          expect(response).to have_http_status(:created)
          expect(JSON.parse(response.body)['data']['id']).to eq('FA82BF279B8673EDF2160766335598353296')
        end
      end
    end

    context 'with a loa1 user' do
      before do
        sign_in_as(loa1_user)
      end

      it 'returns a sid' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)
        VCR.use_cassette('covid_vaccine/vetext/post_vaccine_registry_loa1', match_requests_on: %i[method path]) do
          expect { post '/covid_vaccine/v0/registration', params: { registration: registration_attributes } }
            .to change(CovidVaccine::SubmissionJob.jobs, :size).by(1)
            .and change(CovidVaccine::V0::RegistrationSubmission, :count).by(1)
          expect(response).to have_http_status(:created)
          expect(JSON.parse(response.body)['data']['id']).to eq('FA82BF279B8673EDF2160766335651453297')
        end
      end
    end

    context 'with a loa3 user' do
      before do
        sign_in_as(loa3_user)
      end

      it 'returns a sid' do
        VCR.use_cassette('covid_vaccine/vetext/post_vaccine_registry_loa3', match_requests_on: %i[method path]) do
          expect { post '/covid_vaccine/v0/registration', params: { registration: registration_attributes } }
            .to change(CovidVaccine::SubmissionJob.jobs, :size).by(1)
            .and change(CovidVaccine::V0::RegistrationSubmission, :count).by(1)
          expect(response).to have_http_status(:created)
          body = JSON.parse(response.body)
          expect(body['data']['attributes']).to include(*summary_response_attributes)
          expect(body['data']['attributes']).not_to include(
            *(expected_response_attributes - summary_response_attributes)
          )
          expect(body['data']['attributes']).to include('zip_code' => '94402')
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
          create(:covid_vax_registration,
                 account_id: loa3_user.account_uuid)
        end

        it 'returns the submission record' do
          get '/covid_vaccine/v0/registration'
          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body['data']['id']).to eq(submission.sid)
          expect(body['data']['attributes']).to include(*expected_response_attributes)
          expect(body['data']['attributes']).not_to include('ssn', 'patient_ssn')
          expect(body['data']['attributes']).to include('first_name' => 'Jon',
                                                        'last_name' => 'Doe')
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
    end
  end
end
