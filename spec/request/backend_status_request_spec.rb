# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Backend Status', type: :request do
  include SchemaMatchers

  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:user) { build(:user, :loa3) }

  let(:tz) { ActiveSupport::TimeZone.new(EVSS::GiBillStatus::Service::OPERATING_ZONE) }
  let(:offline_saturday) { tz.parse('17th Mar 2018 19:00:01') }
  let(:online_weekday) { tz.parse('24th Jan 2018 06:00:00') }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  context 'during offline hours on saturday' do
    before { Timecop.freeze(offline_saturday) }
    after { Timecop.return }

    describe '#show' do
      it 'responds 200' do
        get v0_backend_status_url('gibs'), nil, auth_header
        expect(response).to have_http_status(:ok)
      end
      it 'indicates the service is unavailable' do
        get v0_backend_status_url('gibs'), nil, auth_header
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['is_available']).to eq(false)
        expect(json['data']['attributes']['name']).to eq('gibs')
      end
    end
  end

  context 'during online hours on weekday' do
    before { Timecop.freeze(online_weekday) }
    after { Timecop.return }

    describe '#show' do
      it 'responds 200' do
        get v0_backend_status_url('gibs'), nil, auth_header
        expect(response).to have_http_status(:ok)
      end
      it 'indicates the service is unavailable' do
        get v0_backend_status_url('gibs'), nil, auth_header
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['is_available']).to eq(true)
        expect(json['data']['attributes']['name']).to eq('gibs')
      end
    end
  end
end
