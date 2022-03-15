# frozen_string_literal: true

require 'rails_helper'

Rspec.describe MebApi::V0::EducationBenefitsController, type: :request do
  include SchemaMatchers
  include ActiveSupport::Testing::TimeHelpers

  let(:user_details) do
    {
      first_name: 'Herbert',
      last_name: 'Hoover',
      middle_name: '',
      birth_date: '1970-01-01',
      ssn: '796292881'
    }
  end

  let(:claimant_id) { 1 }
  let(:user) { build(:user, :loa3, user_details) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:faraday_response) { double('faraday_connection') }

  before do
    allow(faraday_response).to receive(:env)
    sign_in_as(user)
  end

  describe 'GET /meb_api/v0/claimant_info' do
    context 'Looks up veteran in LTS ' do
      it 'returns a 200 with claimant info' do
        VCR.use_cassette('dgi/post_claimant_info') do
          get '/meb_api/v0/claimant_info'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('dgi/claimant_info_response', { strict: false })
        end
      end
    end
  end

  describe 'GET /meb_api/v0/eligibility' do
    context 'Veteran who has benefit eligibility' do
      it 'returns a 200 with eligibility data' do
        VCR.use_cassette('dgi/get_eligibility') do
          travel_to Time.zone.local(2022, 2, 9, 12) do
            get '/meb_api/v0/eligibility'
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('dgi/eligibility_response', { strict: false })
          end
        end
      end
    end
  end

  describe 'GET /meb_api/v0/claim_letter' do
    context 'Retrieves a veterans claim letter' do
      it 'returns a 200 status when given claimant id as parameter' do
        VCR.use_cassette('dgi/get_claim_letter') do
          get '/meb_api/v0/claim_letter'
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe 'GET /meb_api/v0/claim_status' do
    context 'Retrieves a veterans claim status' do
      it 'returns a 200 status when given claimant id as parameter' do
        VCR.use_cassette('dgi/get_claim_status') do
          get '/meb_api/v0/claim_status'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('dgi/claim_status_response', { strict: false })
        end
      end
    end
  end

  describe 'GET /meb_api/v0/enrollment' do
    context 'Retrieves a veterans enrollments' do
      it 'returns a 200 status when it' do
        VCR.use_cassette('dgi/enrollment') do
          get '/meb_api/v0/enrollment', params: { claimant_id: 1 }
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe 'POST /meb_api/v0/submit_enrollment_verification' do
    context 'Creates a veterans enrollments' do
      it 'returns a 200 status when it' do
        VCR.use_cassette('dgi/submit_enrollment_verification') do
          post '/meb_api/v0/submit_enrollment_verification'
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
