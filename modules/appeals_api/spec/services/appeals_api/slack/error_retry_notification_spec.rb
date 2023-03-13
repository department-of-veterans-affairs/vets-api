# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::Slack::ErrorRetryNotification do
  describe '#message_text' do
    let(:params) do
      {
        'class' => 'PdfSubmitJob',
        'args' => %w[1234 5678],
        'retry_count' => 2,
        'error_class' => 'RuntimeError',
        'error_message' => 'Here there be dragons',
        'failed_at' => 1_613_670_737.966083,
        'retried_at' => 1_613_680_062.5507782
      }
    end

    it 'returns the VSP environment' do
      with_settings(Settings, vsp_environment: 'staging') do
        expect(
          described_class.new(params).message_text
        ).to include('ENVIRONMENT: :construction: staging :construction')
      end
    end

    it 'returns the class that errored' do
      with_settings(Settings, vsp_environment: 'staging') do
        expect(described_class.new(params).message_text).to include('PdfSubmitJob')
      end
    end

    it 'returns the adjusted retry count, if present' do
      with_settings(Settings, vsp_environment: 'sandbox') do
        expect(described_class.new(params).message_text).to include('has hit 3 retries')
        params.delete 'retry_count'
        expect(described_class.new(params).message_text).to include('threw an error')
      end
    end

    it 'returns args passed to job, if present' do
      with_settings(Settings, vsp_environment: 'staging') do
        expect(described_class.new(params).message_text).to include('Job Args: ["1234", "5678"]')
        params.delete 'args'
        expect(described_class.new(params).message_text).not_to include('Job Args:')
      end
    end

    it 'returns the error class and error message' do
      with_settings(Settings, vsp_environment: 'sandbox') do
        expect(described_class.new(params).message_text).to include('RuntimeError')
        expect(described_class.new(params).message_text).to include('Here there be dragons')
      end
    end

    it 'returns the time the job failed' do
      with_settings(Settings, vsp_environment: 'staging') do
        expect(described_class.new(params).message_text).to include('failed at: 2021-02-18 17:52:17 UTC')
      end
    end

    it 'returns the retry time, if present' do
      with_settings(Settings, vsp_environment: 'sandbox') do
        expect(described_class.new(params).message_text).to include('retried at: 2021-02-18 20:27:42 UTC')
        params.delete 'retried_at'
        expect(described_class.new(params).message_text).to include('was not retried')
      end
    end
  end
end
