# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/sidekiq_retry_notifier'

module AppealsApi
  RSpec.describe SidekiqRetryNotifier do
    describe '.notify!' do
      let(:params) do
        {
          'class' => 'HigherLevelReviewPdfSubmitJob',
          'args' => %w[1234 5678],
          'retry_count' => 2,
          'error_class' => 'RuntimeError',
          'error_message' => 'Here there be dragons',
          'failed_at' => 1_613_670_737.966083,
          'retried_at' => 1_613_680_062.5507782
        }
      end

      describe '#message_text' do
        it 'returns the VSP environment' do
          with_settings(Settings, vsp_environment: 'humid') do
            expect(described_class.message_text(params)).to include('ENVIRONMENT: humid')
          end
        end

        it 'returns the class that errored' do
          expect(described_class.message_text(params)).to include('HigherLevelReviewPdfSubmitJob')
        end

        it 'returns the adjusted retry count, if present' do
          expect(described_class.message_text(params)).to include('has hit 3 retries')
          params.delete 'retry_count'
          expect(described_class.message_text(params)).to include('threw an error')
        end

        it 'returns args passed to job, if present' do
          expect(described_class.message_text(params)).to include('Job Args: ["1234", "5678"]')
          params.delete 'args'
          expect(described_class.message_text(params)).not_to include('Job Args:')
        end

        it 'returns the error class and error message' do
          expect(described_class.message_text(params)).to include('RuntimeError')
          expect(described_class.message_text(params)).to include('Here there be dragons')
        end

        it 'returns the time the job failed' do
          expect(described_class.message_text(params)).to include('failed at: 2021-02-18 17:52:17 UTC')
        end

        it 'returns the retry time, if present' do
          expect(described_class.message_text(params)).to include('retried at: 2021-02-18 20:27:42 UTC')
          params.delete 'retried_at'
          expect(described_class.message_text(params)).to include('was not retried')
        end
      end

      it 'sends a network request' do
        with_settings(Settings.modules_appeals_api.slack, api_key: 'api token',
                                                          appeals_channel_id: 'slack channel id') do
          body = {
            text: SidekiqRetryNotifier.message_text(params),
            channel: 'slack channel id'
          }.to_json

          headers = {
            'Content-type' => 'application/json; charset=utf-8',
            'Authorization' => 'Bearer api token'
          }

          allow(Faraday).to receive(:post).with(SidekiqRetryNotifier::API_PATH, body, headers)

          SidekiqRetryNotifier.notify!(params)

          expect(Faraday).to have_received(:post).with(SidekiqRetryNotifier::API_PATH, body, headers)
        end
      end
    end
  end
end
