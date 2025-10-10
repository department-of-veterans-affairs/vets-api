# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::EnrollmentPeriods', type: :request do
  let(:user) { build(:user, :loa3) }
  let(:invalid_user) { build(:user, :loa1, icn: subject.veteran_icn) }

  describe 'GET /index' do
    context 'with valid signed in user' do
      before do
        sign_in_as(user)
      end

      it 'returns http success' do
        VCR.use_cassette('', match_requests_on: %i[uri method body]) do
          get '/v0/enrollment_periods'
          expect(response).to have_http_status(:success)
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
