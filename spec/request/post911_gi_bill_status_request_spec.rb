# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Post 911 GI Bill Status', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
    Settings.evss.mock_gi_bill_status = false
  end

  context 'with a valid evss response' do
    it 'GET /v0/post911_gi_bill_status returns proper json' do
      VCR.use_cassette('evss/gi_bill_status/gi_bill_status') do
        get v0_post911_gi_bill_status_url, nil, auth_header
        byebug
        expect(response).to match_response_schema('post911_gi_bill_status')
        assert_response :success
      end
    end
  end

  # TODO(AJD): this use case happens, 500 status but unauthorized message
  # check with evss that they shouldn't be returning 403 instead
  context 'with an 500 unauthorized response' do
    it 'should return a forbidden response' do
      VCR.use_cassette('evss/gi_bill_status/unauthorized') do
        get v0_post911_gi_bill_status_url, nil, auth_header
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # TODO: - is this a real scenario?
  context 'with a 403 response' do
    it 'should return a forbidden response' do
      VCR.use_cassette('evss/gi_bill_status/gi_bill_status_403') do
        get v0_post911_gi_bill_status_url, nil, auth_header
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # a 500 and does not contain one of the errors defined in:
  # https://csraciapp6.evss.srarad.com/wss-education-services-web/swagger-ui/ext-docs/education-error-keys.html
  context 'with an undefined 500 evss response' do
    it 'should return internal server error' do
      VCR.use_cassette('evss/gi_bill_status/gi_bill_status_500') do
        get v0_post911_gi_bill_status_url, nil, auth_header
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  context 'during offline hours' do
    let(:a_time_outside_hours) { DateTime.parse('3rd Feb 2018 00:15:06-04:00') }
    before { Timecop.freeze(a_time_outside_hours) }
    after { Timecop.return }

    describe '#show' do
      it 'responds 503' do
        get v0_post911_gi_bill_status_url, nil, auth_header
        expect(response).to have_http_status(:service_unavailable)
      end
      it 'containts a Retry-After header' do
        get v0_post911_gi_bill_status_url, nil, auth_header
        expect(response.headers).to include('Retry-After')
      end
    end

    describe '#is_available' do
      it 'returns false' do
        get is_available_v0_post911_gi_bill_status_url, nil, auth_header
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['is_available']).to eq(false)
      end
    end
  end

  context 'with deprecated GibsNotFoundUser class' do
    it 'loads the class for coverage' do
      GibsNotFoundUser
    end
  end
end
