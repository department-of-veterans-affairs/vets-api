# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'

describe SM::Client do
  let(:config) { SM::Configuration.new(attributes_for(:configuration)) }
  let(:session) { SM::ClientSession.new(attributes_for(:session, :valid_user)) }
  let(:invalid_session) { SM::ClientSession.new(attributes_for(:session, :invalid_user)) }

  context 'with valid session and configuration' do
    before(:each) do
      @client = SM::Client.new(config: config, session: session)

      VCR.use_cassette('sm/sessions/10616687/create') do
        @response = @client.get_session
      end
    end

    it 'gets a valid session' do
      expect(@response).to be_a(SM::ClientSession)
      expect(@response.token).not_to be_nil
    end
  end

  context 'with invalid session' do
    it 'gets a valid session' do
      client = SM::Client.new(config: config, session: invalid_session)

      VCR.use_cassette('sm/sessions/106166/create_fail') do
        expect do
          client.get_session
        end.to raise_error(Common::Client::Errors::ClientResponse, 'User was not found')
      end
    end
  end
end
