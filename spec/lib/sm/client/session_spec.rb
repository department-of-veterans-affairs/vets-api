# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

RSpec.describe 'sm client', type: :request do
  let(:user_id) { '10616687' }
  let(:current_user) { build(:user, :mhv) }

  before do
    sign_in_as(current_user)
    allow(User).to receive(:find).and_return(current_user)
  end

  def toggle_feature_flag_for_actor(value)
    allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, current_user).and_return(value)
  end

  after do
    RSpec::Mocks.space.proxy_for(User).reset
    RSpec::Mocks.space.proxy_for(Flipper).reset
  end

  context 'session' do
    it 'session' do
      client = nil
      toggle_feature_flag_for_actor(false)
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
      toggle_feature_flag_for_actor(true)
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
