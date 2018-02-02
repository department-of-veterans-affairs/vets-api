# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'reference_data', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  # to regnerate cassettes see:
  # https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/EVSS%20Integration/evss_rds_socks_proxy.md
  describe 'GET /v0/reference_data/countries' do
    context 'with a 200 evss response', vcr: { cassette_name: 'evss/aws/reference_data/countries' } do
      it 'return a list of countries' do
        get '/v0/reference_data/countries', nil, auth_header
        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('countries')
      end
    end

    context 'with a 401 malformed token response', vcr: { cassette_name: 'evss/aws/reference_data/401_malformed' } do
      before do
        allow_any_instance_of(EVSS::AWS::ReferenceData::Service)
          .to receive(:headers_for_user)
          .and_return({Authorization: 'Bearer abcd12345asd'})
      end
      it 'should return 500' do
        get '/v0/reference_data/countries', nil, auth_header
        # TODO: common evss client thinks this should be 502
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe 'GET /v0/reference_data/states' do
  end
end
