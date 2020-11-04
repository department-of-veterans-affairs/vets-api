# frozen_string_literal: true

require 'rails_helper'
require 'carma/client/client'

RSpec.describe CARMA::Client::Client, type: :model do
  let(:restforce_client) do
    restforce_client = double
    expect(subject).to receive(:get_client).and_return(restforce_client)

    if Settings['salesforce-carma'].mock
      builder = double
      expect(restforce_client).to receive(:builder).and_return(builder)
      expect(builder).to receive(:insert_before).with(Faraday::Adapter::NetHttp, Betamocks::Middleware)
    end

    restforce_client
  end

  describe 'configuration' do
    it 'sets the proper constants' do
      expect(described_class::STATSD_KEY_PREFIX).to eq('api.carma')
      expect(described_class::SALESFORCE_INSTANCE_URL).to eq(Settings['salesforce-carma'].url)
      expect(described_class::CONSUMER_KEY).to eq(Settings['salesforce-carma'].consumer_key)
      expect(described_class::SIGNING_KEY_PATH).to eq(Settings['salesforce-carma'].signing_key_path)
      expect(described_class::SALESFORCE_USERNAME).to eq(Settings['salesforce-carma'].username)
    end
  end

  describe '#create_submission' do
    def self.test_carma_submission
      it 'accepts a payload and submits to CARMA' do
        payload           = { 'my' => 'data' }
        response_double   = double

        expect(restforce_client).to receive(:post).with(
          '/services/apexrest/carma/v1/1010-cg-submissions',
          payload,
          'Content-Type': 'application/json',
          'Sforce-Auto-Assign': 'FALSE'
        ).and_return(
          response_double
        )

        expect(response_double).to receive(:body).and_return(:response_token)
        response = subject.create_submission(payload)
        expect(response).to eq(:response_token)
      end
    end

    context 'with betamocks enabled' do
      test_carma_submission
    end

    context 'with betamocks disabled' do
      before do
        Settings['salesforce-carma'].mock = false
      end

      test_carma_submission
    end
  end

  describe '#upload_attachments' do
    it 'accepts a payload and submitts to CARMA' do
      payload           = { 'my' => 'data' }
      response_double   = double

      expect(restforce_client).to receive(:post).with(
        '/services/data/v47.0/composite/tree/ContentVersion',
        payload,
        'Content-Type': 'application/json'
      ).and_return(
        response_double
      )

      expect(response_double).to receive(:body).and_return(:response_token)
      response = subject.upload_attachments(payload)
      expect(response).to eq(:response_token)
    end
  end
end
