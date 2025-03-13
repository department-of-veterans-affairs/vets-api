# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe 'sm client' do
  before do
    VCR.use_cassette 'sm_client/session' do
      @client ||= begin
        client = SM::Client.new(session: { user_id: '10616687' })
        client.authenticate
        client
      end
    end
  end

  let(:client) { @client }

  context 'preferences' do
    it 'fetches email settings for notifications', :vcr do
      client_response = client.get_preferences
      expect(client_response.email_address).to eq('muazzam.khan@va.gov')
      expect(client_response.frequency).to eq('daily')
    end

    it 'fetches list of email frequency constants', :vcr do
      client_response = client.get_preferences_frequency_list
      expect(client_response[:data]).to eq('0': 'None', '1': 'Each message', '2': 'Once daily')
    end

    it 'sets the email notification settings', :vcr do
      client_response = client.post_preferences(email_address: 'kamyar.karshenas@va.gov', frequency: 'none')
      expect(client_response.email_address).to eq('kamyar.karshenas@va.gov')
      expect(client_response.frequency).to eq('none')

      # Change it back to original to make test idempotent
      client_response = client.post_preferences(email_address: 'muazzam.khan@va.gov', frequency: 'daily')
      expect(client_response.email_address).to eq('muazzam.khan@va.gov')
      expect(client_response.frequency).to eq('daily')
    end

    it 'does not change anything if email address is invalid', :vcr do
      expect { client.post_preferences(email_address: 'invalid', frequency: 'none') }
        .to raise_error(Common::Exceptions::ValidationErrors)
    end

    it 'raises a backend service exception when email includes spaces', :vcr do
      expect { client.post_preferences(email_address: 'kamyar karshenas@va.gov', frequency: 'none') }
        .to raise_error(Common::Exceptions::BackendServiceException)
    end

    it 'fetches the signature preferences', :vcr do
      client_response = client.get_signature[:data]
      expect(client_response[:include_signature]).to be(true)
      expect(client_response[:signature_name]).to eq('Test Mark')
      expect(client_response[:signature_title]).to eq('Test Title API')
    end

    it 'sets the signature preferences', :vcr do
      params = { signature_name: 'Test Mark', include_signature: false, signature_title: 'Test Title API' }
      client_response = client.post_signature(params)[:data]
      expect(client_response[:include_signature]).to be(true)
      expect(client_response[:signature_name]).to eq('Test Mark')
      expect(client_response[:signature_title]).to eq('Test Title API')
    end
  end
end
