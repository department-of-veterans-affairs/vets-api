# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Form1095Bs', type: :request do
  let(:user) { build(:user, :loa3, icn: '1012667145V762142') }
  let(:invalid_user) { build(:user, :loa1) }

  before do
    allow(Flipper).to receive(:enabled?).with(:fetch_1095b_from_enrollment_system, any_args).and_return(true)
    Timecop.freeze(Time.zone.parse('2025-03-05T08:00:00Z'))
  end

  after { Timecop.return }

  describe 'GET /download_pdf' do
    context 'with valid user' do
      before do
        sign_in_as(user)
      end

      it 'returns http success' do
        VCR.use_cassette('veteran_enrollment_system/form1095_b/get_form_success',
                         { match_requests_on: %i[method uri] }) do
          get '/v0/form1095_bs/download_pdf/2024'
          expect(response).to have_http_status(:success)
        end
      end

      it 'returns a PDF form' do
        VCR.use_cassette('veteran_enrollment_system/form1095_b/get_form_success',
                         { match_requests_on: %i[method uri] }) do
          get '/v0/form1095_bs/download_pdf/2024'
          expect(response.content_type).to eq('application/pdf')
        end
      end

      it 'returns error from enrollment system' do
        VCR.use_cassette('veteran_enrollment_system/form1095_b/get_form_not_found',
                         { match_requests_on: %i[method uri] }) do
          get '/v0/form1095_bs/download_pdf/2024'
          expect(response).to have_http_status(:not_found)
        end
      end

      # this will be irrelevant after we add the template
      it 'throws 422 when template is not available' do
        get '/v0/form1095_bs/download_pdf/2023'
        expect(response).to have_http_status(:unprocessable_entity)
      end

      # 2021 is the one unsupported year for which we have a template
      it 'throws 422 when requested year is not in supported range' do
        get '/v0/form1095_bs/download_pdf/2021'
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with invalid user' do
      before do
        sign_in_as(invalid_user)
      end

      it 'returns http 403' do
        get '/v0/form1095_bs/download_pdf/2021'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user is not logged in' do
      it 'returns http 401' do
        get '/v0/form1095_bs/download_pdf/2021'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /download_txt for valid user' do
    context 'with valid user' do
      before do
        sign_in_as(user)
      end

      it 'returns http success' do
        VCR.use_cassette('veteran_enrollment_system/form1095_b/get_form_success',
                         { match_requests_on: %i[method uri] }) do
          get '/v0/form1095_bs/download_txt/2024'
          expect(response).to have_http_status(:success)
        end
      end

      it 'returns a txt form' do
        VCR.use_cassette('veteran_enrollment_system/form1095_b/get_form_success',
                         { match_requests_on: %i[method uri] }) do
          get '/v0/form1095_bs/download_txt/2024'
          expect(response.content_type).to eq('text/plain')
        end
      end

      it 'returns error from enrollment system' do
        VCR.use_cassette('veteran_enrollment_system/form1095_b/get_form_not_found',
                         { match_requests_on: %i[method uri] }) do
          get '/v0/form1095_bs/download_txt/2024'
          expect(response).to have_http_status(:not_found)
        end
      end

      # this will be irrelevant after we add the template
      it 'throws 422 when template is not available' do
        get '/v0/form1095_bs/download_txt/2023'
        expect(response).to have_http_status(:unprocessable_entity)
      end

      # 2021 is the one unsupported year for which we have a template
      it 'throws 422 when requested year is not in supported range' do
        get '/v0/form1095_bs/download_txt/2021'
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with invalid user' do
      before do
        sign_in_as(invalid_user)
      end

      it 'returns http 403' do
        get '/v0/form1095_bs/download_txt/2021'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user is not logged in' do
      it 'returns http 401' do
        get '/v0/form1095_bs/download_txt/2021'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /available_forms' do
    context 'with valid user' do
      before do
        sign_in_as(user)
      end

      it 'returns success with list of available form years during allowed date range' do
        VCR.use_cassette('veteran_enrollment_system/enrollment_periods/get_success',
                         { match_requests_on: %i[method uri] }) do
          get '/v0/form1095_bs/available_forms'
        end
        expect(response).to have_http_status(:success)
        expect(response.parsed_body.deep_symbolize_keys).to eq(
          { available_forms: [
            { year: 2024,
              last_updated: nil }
          ] }
        )
      end

      context 'when user not found on enrollment system' do
        it 'returns success with an empty list' do
          VCR.use_cassette('veteran_enrollment_system/enrollment_periods/get_not_found',
                           { match_requests_on: %i[method uri] }) do
            get '/v0/form1095_bs/available_forms'
          end
          expect(response).to have_http_status(:success)
          expect(response.parsed_body.deep_symbolize_keys).to eq(
            { available_forms: [] }
          )
        end
      end

      context 'when user was not enrolled during allowed date range' do
        # per the vcr cassette, user was not enrolled in 2023
        before { Timecop.freeze(Time.zone.parse('2024-03-05T08:00:00Z')) }
        after { Timecop.return }

        it 'returns an empty array' do
          VCR.use_cassette('veteran_enrollment_system/enrollment_periods/get_success',
                           { match_requests_on: %i[method uri] }) do
            get '/v0/form1095_bs/available_forms'
          end
          expect(response).to have_http_status(:success)
          expect(response.parsed_body.deep_symbolize_keys).to eq(
            { available_forms: [] }
          )
        end
      end

      context 'when an error is received from the enrollment system' do
        it 'returns appropriate error status' do
          # stubbing instead of using cassette because I haven't been able to produce errors other than 404 on
          # enrollment system
          upstream_response = OpenStruct.new(status: 400)
          allow_any_instance_of(VeteranEnrollmentSystem::EnrollmentPeriods::Service).to \
            receive(:perform).and_return(upstream_response)
          get '/v0/form1095_bs/available_forms'
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context 'with invalid user' do
      before do
        sign_in_as(invalid_user)
      end

      it 'returns http 403' do
        get '/v0/form1095_bs/available_forms'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user is not logged in' do
      it 'returns http 401' do
        get '/v0/form1095_bs/available_forms'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
