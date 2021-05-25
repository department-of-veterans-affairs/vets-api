# frozen_string_literal: true

require 'rails_helper'
require 'carma/client/client'

RSpec.describe CARMA::Client::Client, type: :model do
  let(:restforce_client) do
    restforce_client = double
    expect(subject).to receive(:get_client).and_return(restforce_client)

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

  def self.test_carma_submission
    describe '#create_submission' do
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
  end

  def self.test_upload_attachments
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

  context 'with betamocks enabled' do
    before do
      expect(Settings['salesforce-carma']).to receive(:mock).and_return(true)

      builder = double
      expect(restforce_client).to receive(:builder).and_return(builder)
      expect(builder).to receive(:adapter).with(Faraday::Adapter::NetHttp, Betamocks::Middleware)
    end

    test_carma_submission

    test_upload_attachments
  end

  context 'with betamocks disabled' do
    before do
      expect(Settings['salesforce-carma']).to receive(:mock).and_return(false)
      expect(restforce_client).not_to receive(:builder)
    end

    test_carma_submission

    test_upload_attachments
  end
end
