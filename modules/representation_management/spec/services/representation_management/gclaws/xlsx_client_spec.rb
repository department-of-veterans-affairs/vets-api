# frozen_string_literal: true

require 'rails_helper'
require 'httpclient'

RSpec.describe RepresentationManagement::GCLAWS::XlsxClient do
  subject { described_class }

  let(:test_url) { 'https://ssrs.example.com/reports/accreditation.xlsx' }
  let(:test_username) { 'test_user' }
  let(:test_password) { 'test_password' }
  let(:xlsx_content_type) { 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }
  let(:xlsx_binary_content) { 'PK\x03\x04...' } # Mock XLSX binary content
  let(:error_log_prefix) { 'RepresentationManagement::GCLAWS::XlsxClient error:' }

  before do
    allow(Settings.gclaws).to receive(:accreditation_xlsx).and_return(
      OpenStruct.new(
        url: test_url,
        username: test_username,
        password: test_password
      )
    )

    # Mock the Slack client
    slack_client = instance_double(SlackNotify::Client)
    allow(SlackNotify::Client).to receive(:new).and_return(slack_client)
    allow(slack_client).to receive(:notify)
  end

  describe '.download_accreditation_xlsx' do
    context 'when the request is successful' do
      it 'returns binary content when content-type is correct' do
        stub_request(:get, test_url)
          .to_return(
            status: 200,
            body: xlsx_binary_content,
            headers: { 'Content-Type' => xlsx_content_type }
          )

        result = subject.download_accreditation_xlsx

        expect(result[:success]).to be true
        expect(result[:data]).to eq(xlsx_binary_content)
      end

      it 'handles content-type with charset parameter' do
        stub_request(:get, test_url)
          .to_return(
            status: 200,
            body: xlsx_binary_content,
            headers: { 'Content-Type' => "#{xlsx_content_type}; charset=utf-8" }
          )

        result = subject.download_accreditation_xlsx

        expect(result[:success]).to be true
        expect(result[:data]).to eq(xlsx_binary_content)
      end
    end

    context 'when content-type is invalid' do
      it 'returns an error for text/html content-type' do
        stub_request(:get, test_url)
          .to_return(
            status: 200,
            body: '<html>Error page</html>',
            headers: { 'Content-Type' => 'text/html' }
          )

        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} GCLAWS XLSX invalid_content_type error/
        )

        result = subject.download_accreditation_xlsx

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid content type: text/html')
        expect(result[:status]).to eq(:unprocessable_entity)
      end

      it 'returns an error for application/json content-type' do
        stub_request(:get, test_url)
          .to_return(
            status: 200,
            body: '{"error": "not xlsx"}',
            headers: { 'Content-Type' => 'application/json' }
          )

        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} GCLAWS XLSX invalid_content_type error/
        )

        result = subject.download_accreditation_xlsx

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid content type: application/json')
        expect(result[:status]).to eq(:unprocessable_entity)
      end

      it 'returns an error when content-type header is missing' do
        stub_request(:get, test_url)
          .to_return(
            status: 200,
            body: xlsx_binary_content,
            headers: {}
          )

        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} GCLAWS XLSX invalid_content_type error/
        )

        result = subject.download_accreditation_xlsx

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid content type: ')
        expect(result[:status]).to eq(:unprocessable_entity)
      end
    end

    context 'when the request is unauthorized (401)' do
      it 'returns an unauthorized error' do
        stub_request(:get, test_url)
          .to_return(status: 401, body: 'Unauthorized')

        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} GCLAWS XLSX unauthorized error/
        )

        result = subject.download_accreditation_xlsx

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX unauthorized')
        expect(result[:status]).to eq(:unauthorized)
      end
    end

    context 'when the server returns an error status' do
      it 'returns a bad gateway error for 500 status' do
        stub_request(:get, test_url)
          .to_return(status: 500, body: 'Internal Server Error')

        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} GCLAWS XLSX http_error error/
        )

        result = subject.download_accreditation_xlsx

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX request failed with status 500')
        expect(result[:status]).to eq(:bad_gateway)
      end

      it 'returns a bad gateway error for 503 status' do
        stub_request(:get, test_url)
          .to_return(status: 503, body: 'Service Unavailable')

        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} GCLAWS XLSX http_error error/
        )

        result = subject.download_accreditation_xlsx

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX request failed with status 503')
        expect(result[:status]).to eq(:bad_gateway)
      end
    end

    context 'when the connection times out' do
      it 'returns a timeout error' do
        stub_request(:get, test_url).to_timeout

        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} GCLAWS XLSX timeout error/
        )

        result = subject.download_accreditation_xlsx

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX download timed out')
        expect(result[:status]).to eq(:request_timeout)
      end
    end

    context 'when the connection fails' do
      it 'returns a service unavailable error for connection refused' do
        stub_request(:get, test_url).to_raise(Errno::ECONNREFUSED.new('Connection refused'))

        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} GCLAWS XLSX connection_failed error/
        )

        result = subject.download_accreditation_xlsx

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX service unavailable')
        expect(result[:status]).to eq(:service_unavailable)
      end

      it 'returns a service unavailable error for socket error' do
        stub_request(:get, test_url).to_raise(SocketError.new('getaddrinfo: Name or service not known'))

        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} GCLAWS XLSX connection_failed error/
        )

        result = subject.download_accreditation_xlsx

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX service unavailable')
        expect(result[:status]).to eq(:service_unavailable)
      end

      it 'returns a service unavailable error for host unreachable' do
        stub_request(:get, test_url).to_raise(Errno::EHOSTUNREACH.new('No route to host'))

        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} GCLAWS XLSX connection_failed error/
        )

        result = subject.download_accreditation_xlsx

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX service unavailable')
        expect(result[:status]).to eq(:service_unavailable)
      end
    end

    context 'when an unexpected error occurs' do
      it 'returns an internal server error' do
        stub_request(:get, test_url).to_raise(StandardError.new('Something went wrong'))

        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} GCLAWS XLSX unexpected error/
        )

        result = subject.download_accreditation_xlsx

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX unexpected error: Something went wrong')
        expect(result[:status]).to eq(:internal_server_error)
      end
    end
  end

  describe '.notify_slack_error' do
    context 'in production environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
      end

      it 'sends a Slack notification' do
        slack_client = instance_double(SlackNotify::Client)
        allow(SlackNotify::Client).to receive(:new).and_return(slack_client)
        allow(slack_client).to receive(:notify)

        stub_request(:get, test_url)
          .to_return(status: 401, body: 'Unauthorized')

        # Suppress the expected logger error
        allow(Rails.logger).to receive(:error)

        subject.download_accreditation_xlsx

        expect(slack_client).to have_received(:notify).with(
          a_string_including('GCLAWS XLSX Download Error Alert')
        )
      end
    end

    context 'in non-production environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('staging')
      end

      it 'does not send a Slack notification' do
        slack_client = instance_double(SlackNotify::Client)
        allow(SlackNotify::Client).to receive(:new).and_return(slack_client)
        allow(slack_client).to receive(:notify)

        stub_request(:get, test_url)
          .to_return(status: 401, body: 'Unauthorized')

        # Suppress the expected logger error
        allow(Rails.logger).to receive(:error)

        subject.download_accreditation_xlsx

        expect(slack_client).not_to have_received(:notify)
      end
    end

    context 'when Slack notification fails' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
      end

      it 'logs the Slack failure but does not raise' do
        slack_client = instance_double(SlackNotify::Client)
        allow(SlackNotify::Client).to receive(:new).and_return(slack_client)
        allow(slack_client).to receive(:notify).and_raise(StandardError.new('Slack API error'))

        stub_request(:get, test_url)
          .to_return(status: 401, body: 'Unauthorized')

        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} GCLAWS XLSX unauthorized error/
        )
        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} Failed to send Slack notification/
        )

        # Should not raise, just log
        expect { subject.download_accreditation_xlsx }.not_to raise_error
      end
    end
  end

  describe '.extract_content_type' do
    it 'extracts content type without charset' do
      response = instance_double(HTTP::Message, content_type: xlsx_content_type)
      expect(subject.extract_content_type(response)).to eq(xlsx_content_type)
    end

    it 'strips charset from content type' do
      response = instance_double(HTTP::Message, content_type: "#{xlsx_content_type}; charset=utf-8")
      expect(subject.extract_content_type(response)).to eq(xlsx_content_type)
    end

    it 'handles nil content type' do
      response = instance_double(HTTP::Message, content_type: nil)
      expect(subject.extract_content_type(response)).to eq('')
    end

    it 'handles empty content type' do
      response = instance_double(HTTP::Message, content_type: '')
      expect(subject.extract_content_type(response)).to eq('')
    end
  end
end
