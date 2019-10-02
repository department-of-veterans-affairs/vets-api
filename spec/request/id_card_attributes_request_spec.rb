# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Requesting ID Card Attributes', type: :request do
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }
  let(:current_user) { build(:user, :loa3) }
  let(:service_episodes) { [build(:service_episode)] }

  before do
    Settings.vic.signing_key_path = "#{::Rails.root}/spec/support/certificates/vic-signing-key.pem"
    sign_in_as(current_user)
  end

  describe '#show /v0/id_card/attributes' do
    it 'should return a signed redirect URL' do
      expect_any_instance_of(EMISRedis::MilitaryInformation)
        .to receive(:service_episodes_by_date).at_least(:once).and_return(service_episodes)
      expect_any_instance_of(EMISRedis::VeteranStatus)
        .to receive(:title38_status).at_least(:once).and_return('V1')
      get '/v0/id_card/attributes', headers: auth_header
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      url = json['url']
      expect(url).to be
      traits = json['traits']
      expect(traits).to be_key('edipi')
      expect(traits).to be_key('firstname')
      expect(traits).to be_key('lastname')
      expect(traits).to be_key('title38status')
      expect(traits).to be_key('branchofservice')
      expect(traits).to be_key('dischargetype')
      expect(traits).to be_key('timestamp')
      expect(traits).to be_key('signature')
    end

    it 'should return Bad Gateway if military information not retrievable' do
      expect_any_instance_of(EMISRedis::VeteranStatus)
        .to receive(:title38_status).at_least(:once).and_return('V1')
      expect_any_instance_of(EMISRedis::MilitaryInformation)
        .to receive(:service_episodes_by_date).and_raise(StandardError)
      get '/v0/id_card/attributes', headers: auth_header
      expect(response).to have_http_status(:bad_gateway)
    end

    it 'should return VIC002 if title38status is not retrievable' do
      allow_any_instance_of(EMISRedis::VeteranStatus)
        .to receive(:title38_status).and_return(nil)
      get '/v0/id_card/attributes', headers: auth_header
      expect(JSON.parse(response.body)['errors'][0]['code']).to eq(
        'VIC002'
      )
    end

    it 'should return Forbidden for non-veteran user' do
      allow_any_instance_of(EMISRedis::VeteranStatus)
        .to receive(:title38_status).and_return('V2')
      get '/v0/id_card/attributes', headers: auth_header
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'][0]['code']).to eq(
        'VICV2'
      )
    end

    it 'should return Forbidden when veteran status not retrievable' do
      expect_any_instance_of(EMISRedis::VeteranStatus)
        .to receive(:title38_status).and_raise(StandardError)
      get '/v0/id_card/attributes', headers: auth_header
      expect(response).to have_http_status(:forbidden)
    end
  end
end
