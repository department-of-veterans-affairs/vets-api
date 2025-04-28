# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

RSpec.describe 'sm client', type: :request do
  let(:user_id) { '10616687' }
  let(:current_user) { build(:user, :mhv) }

  # Ensure Flipper is mocked before the VCR block - remove this when AWS API GW is fully implemented
before do
  allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_migrate_to_api_gateway).and_return(false)
end

  before do
    sign_in_as(current_user)
  end

  context 'session' do
    it 'session' do
      client = nil
      VCR.use_cassette 'sm_client/session' do
        client || begin
          client = SM::Client.new(session: { user_id:, user_uuid: current_user.uuid })
          client.authenticate
          client
        end
      end
      expect(client).to be_a(SM::Client)
      expect(client.session).to be_a(SM::ClientSession)
      expect(client.session.expires_at).not_to be_nil
    end

    it 'session OH initial pull' do
      allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, instance_of(User)).and_return(true)
      client = nil
      VCR.use_cassette('sm_session/session_oh_initial_pull') do
        client ||= begin
          client = SM::Client.new(session: { user_id:, user_uuid: current_user.uuid })
          client.authenticate
          client
        end
      end
      expect(client).to be_a(SM::Client)
      expect(client.session).to be_a(SM::ClientSession)
      expect(client.session.expires_at).not_to be_nil
    end
  end
end
