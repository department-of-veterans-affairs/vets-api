# frozen_string_literal: true

require 'rails_helper'
require 'contention_classification/client'

RSpec.describe ContentionClassification::Client do
  let(:client) { ContentionClassification::Client.new }
  let(:classification_contention_params) do
    { contentions: [
        {
          diagnostic_code: 1234,
          contention_type: 'INCREASE',
          contention_text: 'A CFI contention'
        },
        {
          contention_text: 'Asthma',
          contention_type: 'NEW'
        },
        {
          contention_text: 'right acl tear',
          contention_type: 'NEW'
        }
      ],
      claim_id: 4567,
      form526_submission_id: 789 }
  end
  let(:max_ratings_params) do
    {
      diagnostic_codes: [1234]
    }
  end

  describe 'making classification contention requests to expanded classifier' do
    subject { client.classify_vagov_contentions_expanded(classification_contention_params) }

    context 'valid requests' do
      let(:generic_response) do
        double(
          'contention classification response', status: 200,
                                                body: {
                                                  contentions: [
                                                    { classification_code: '99999', classification_name: 'namey' },
                                                    { classification_code: '9012', classification_name: 'Respiratory' },
                                                    {
                                                      classification_code: '8997',
                                                      classification_name: 'Musculoskeletal - Knee'
                                                    }
                                                  ]
                                                }.as_json
        )
      end

      before do
        allow(client).to receive(:perform).and_return generic_response
      end

      it 'returns the api response for the expanded classification' do
        expect(subject).to eq generic_response
      end
    end

    context 'invalid requests' do
      let(:error_response) do
        double(
          'contention classification response', status: 400,
                                                body: { error: 'Invalid request' }.as_json
        )
      end

      before do
        allow(client).to receive(:perform).and_return error_response
      end

      it 'returns the error response for the expanded classification' do
        expect(subject).to eq error_response
      end
    end

    context 'server error' do
      let(:server_error_response) do
        double(
          'contention classification response', status: 500,
                                                body: { error: 'Internal server error' }.as_json
        )
      end

      before do
        allow(client).to receive(:perform).and_return server_error_response
      end

      it 'returns the server error response for the expanded classification' do
        expect(subject).to eq server_error_response
      end
    end

    [
      Faraday::ConnectionFailed.new('connection failed'),
      Faraday::TimeoutError.new('test timeout'),
      Faraday::ServerError.new('test server error')
    ].each do |error|
      context "when request raises #{error.class}" do
        before do
          allow(client).to receive(:perform).and_raise(error)
        end

        it 'logs and re-raises the exception' do
          expect(Rails.logger).to receive(:error).with(
            'ContentionClassification::Client Faraday error on path ' \
            "#{Settings.contention_classification_api.expanded_contention_classification_path}: #{error.message}"
          )
          expect { subject }.to raise_error(error.class)
        end
      end
    end
  end
end
