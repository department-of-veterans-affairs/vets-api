# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CARMA::Client::Client, type: :model do
  describe 'configuration' do
    it 'sets the proper constants' do
      expect(described_class::STATSD_KEY_PREFIX).to eq('api.carma')
      # SALESFORCE_INSTANCE_URL will eventually become env dependent, need to map our env to theirs
      expect(described_class::SALESFORCE_INSTANCE_URL).to eq('https://va--carmadev.my.salesforce.com')
      expect(described_class::CONSUMER_KEY).to eq(Settings['salesforce-carma'].consumer_key)
      expect(described_class::SIGNING_KEY_PATH).to eq(Settings['salesforce-carma'].signing_key_path)
      expect(described_class::SALESFORCE_USERNAME).to eq(Settings['salesforce-carma'].username)
    end
  end

  describe '#create_submission' do
    let(:client) { described_class.new }

    it 'accepts a payload and submitts to CARMA' do
      payload = { my: 'data' }

      client_double = double
      response_double = double

      expect(client).to receive(:get_client).and_return(client_double)

      expect(client_double).to receive(:post)
        .with(
          '/services/apexrest/carma/v1/1010-cg-submissions',
          payload,
          'Content-Type': 'application/json'
        )
        .and_return(response_double)
      expect(response_double).to receive(:body).and_return(:response_token)

      response = client.create_submission(payload)

      expect(response).to eq(:response_token)
    end
  end
end
