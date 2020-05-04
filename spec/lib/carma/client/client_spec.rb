# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CARMA::Client::Client, type: :model do
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
          'Content-Type': 'application/json',
          'Sforce-Auto-Assign': 'FALSE'
        )
        .and_return(response_double)
      expect(response_double).to receive(:body).and_return(:response_token)

      response = client.create_submission(payload)

      expect(response).to eq(:response_token)
    end
  end

  describe '#create_submission_stub' do
    timestamp = DateTime.parse('2020-03-09T06:48:59-04:00')

    it 'returns a hard coded response', run_at: timestamp.iso8601 do
      payload = nil

      # rubocop:disable RSpec/SubjectStub
      expect(subject).not_to receive(:get_client)
      # rubocop:enable RSpec/SubjectStub

      response = subject.create_submission_stub(payload)

      expect(response['message']).to eq('Application Received')
      expect(response['data']).to be_present
      expect(response['data']['carmacase']).to be_present
      expect(response['data']['carmacase']['id']).to eq 'aB935000000F3VnCAK'
      expect(DateTime.parse(response['data']['carmacase']['createdAt'])).to eq timestamp
    end
  end
end
