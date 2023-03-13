# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Post 911 GI Bill Status' do
  include SchemaMatchers

  let(:tz) { ActiveSupport::TimeZone.new(EVSS::GiBillStatus::Service::OPERATING_ZONE) }
  let(:noon) { tz.parse('1st Feb 2018 12:00:00') }
  let(:midnight) { tz.parse('15th Mar 2018 00:00:00') }

  before do
    sign_in
    allow(Settings.evss).to receive(:mock_gi_bill_status).and_return(false)
  end

  context 'inside working hours' do
    before { Timecop.freeze(noon) }

    after { Timecop.return }

    context 'with a valid evss response' do
      it 'GET /v0/post911_gi_bill_status returns proper json' do
        VCR.use_cassette('evss/gi_bill_status/gi_bill_status') do
          get v0_post911_gi_bill_status_url, params: nil
          expect(response).to match_response_schema('post911_gi_bill_status')
          assert_response :success
        end
      end
    end

    # TODO(AJD): this use case happens, 500 status but unauthorized message
    # check with evss that they shouldn't be returning 403 instead
    context 'with an 500 unauthorized response' do
      it 'returns a forbidden response' do
        VCR.use_cassette('evss/gi_bill_status/unauthorized') do
          get v0_post911_gi_bill_status_url, params: nil
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    # TODO: - is this a real scenario?
    context 'with a 403 response' do
      it 'returns a forbidden response' do
        VCR.use_cassette('evss/gi_bill_status/gi_bill_status_403') do
          get v0_post911_gi_bill_status_url, params: nil
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    # a 500 and does not contain one of the errors defined in:
    # https://csraciapp6.evss.srarad.com/wss-education-services-web/swagger-ui/ext-docs/education-error-keys.html
    context 'with an undefined 500 evss response' do
      it 'returns internal server error' do
        VCR.use_cassette('evss/gi_bill_status/gi_bill_status_500') do
          get v0_post911_gi_bill_status_url, params: nil
          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end
  end

  context 'outside working hours' do
    before { Timecop.freeze(midnight) }

    after { Timecop.return }

    it 'returns 503' do
      get v0_post911_gi_bill_status_url, params: nil
      expect(response).to have_http_status(:service_unavailable)
    end

    it 'includes a Retry-After header' do
      get v0_post911_gi_bill_status_url, params: nil
      expect(response.headers).to include('Retry-After')
    end

    it 'ignores OutsideWorkingHours exception' do
      expect(Raven).not_to receive(:capture_message)
      get v0_post911_gi_bill_status_url, params: nil
    end
  end

  context 'with deprecated GibsNotFoundUser class' do
    it 'loads the class for coverage' do
      GibsNotFoundUser
    end
  end
end
