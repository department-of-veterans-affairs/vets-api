# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::EnrollmentPeriods', type: :request do
  let(:user) { build(:user, :loa3, icn: '1012667145V762142') }
  let(:invalid_user) { build(:user, :loa1) }

  describe 'GET /index' do
    context 'with valid signed in user' do
      before do
        sign_in_as(user)
      end

      it 'returns http success' do
        VCR.use_cassette('veteran_enrollment_system/enrollment_periods/get_success',
                         match_requests_on: %i[uri method body]) do
          get '/v0/enrollment_periods'
          expect(response).to have_http_status(:success)
          expect(response.parsed_body).to eq({ 'enrollment_periods' => [
                                               { 'startDate' => '2024-03-05',
                                                 'endDate' => '2024-03-05' },
                                               { 'startDate' => '2019-03-05',
                                                 'endDate' => '2022-03-05' },
                                               { 'startDate' => '2010-03-05',
                                                 'endDate' => '2015-03-05' }
                                             ] })
        end
      end

      it 'returns appropriate error code' do
        VCR.use_cassette('veteran_enrollment_system/enrollment_periods/get_not_found',
                         match_requests_on: %i[uri method body]) do
          get '/v0/enrollment_periods'
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'with invalid user' do
      before do
        sign_in_as(invalid_user)
      end

      it 'returns http 403' do
        get '/v0/enrollment_periods'
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
