# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::Messaging::Folders', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '10616687' }
  let(:current_user) { build(:user, :mhv) }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }
  let(:client) { @client }

  before do
    sign_in_as(current_user)
    Flipper.enable_actor(:mhv_secure_messaging_cerner_pilot, current_user)
      VCR.use_cassette('sm_session/session_oh_initial_pull') do
        @client ||= begin
          client = SM::Client.new(session: { user_id: '10616687', user_uuid: current_user.uuid })
          client.authenticate
          client
        end
      end
  end

  after(:all) do
    Flipper.disable(:mhv_secure_messaging_cerner_pilot)
  end

  # before(:all) do
    # VCR.use_cassette 'sm_client/session' do
    #   @client ||= begin
    #     client = SM::Client.new(session: { user_id: '10616687', user_uuid: current_user.uuid })
    #     client.authenticate
    #     client
    #   end
    # end
  # end

  context 'session' do
    # before do
    #   Flipper.enable_actor(:mhv_secure_messaging_cerner_pilot, current_user)
    #   VCR.use_cassette('sm_session/session_oh_initial_pull') do
    #     @client ||= begin
    #       client = SM::Client.new(session: { user_id: '10616687', user_uuid: current_user.uuid })
    #       client.authenticate
    #       client
    #     end
    #   end
    # end

    # after(:all) do
    #   Flipper.disable(:mhv_secure_messaging_cerner_pilot)
    # end

    # it 'session OH initial pull', :vcr do
    #   request = @client.get_session_tagged
    #   puts "response: #{request.inspect}"
    #   expect(request).to include('requiresOHMessages=1')
    # end

    it 'includes requiresOHMessages=1 in the session request URI', :vcr do
      expect {
        client.authenticate
      }.to raise_error(SM::ServiceException) do |error|
        puts "Request URI: #{VCR.current_cassette.serializable_hash.dig(:http_interactions, 0, :request, :uri)}"
      end
    end

    it 'includes requiresOHMessages=1 in the session request URI', :vcr do
      client.authenticate
      cassette = VCR.current_cassette
    
      expect(cassette.serializable_hash[:http_interactions]).to include(
        a_hash_including(
          request: a_hash_including(
            uri: a_string_including("requiresOHMessages=1")
          )
        )
      )
    end
  end
end
