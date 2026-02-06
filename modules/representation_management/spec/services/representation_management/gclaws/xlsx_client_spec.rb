# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::GCLAWS::XlsxClient do
  subject { described_class }

  let(:test_url) { 'https://ssrs.example.com/reports/accreditation.xlsx' }
  let(:test_hostname) { 'ssrs.example.com' }
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
    context 'when block is not provided' do
      it 'raises ArgumentError' do
        expect { subject.download_accreditation_xlsx }.to raise_error(ArgumentError, 'Block required')
      end
    end

    context 'when configuration is invalid' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'returns a structured error when URL is missing' do
        allow(Settings.gclaws).to receive(:accreditation_xlsx).and_return(
          OpenStruct.new(
            url: nil,
            username: test_username,
            password: test_password
          )
        )

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX configuration_error error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to match(/GCLAWS XLSX configuration error/)
        expect(result[:error]).to match(/URL is missing or empty/)
        expect(result[:status]).to eq(:internal_server_error)
      end

      it 'returns a structured error when username is missing' do
        allow(Settings.gclaws).to receive(:accreditation_xlsx).and_return(
          OpenStruct.new(
            url: test_url,
            username: nil,
            password: test_password
          )
        )

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX configuration_error error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to match(/GCLAWS XLSX configuration error/)
        expect(result[:error]).to match(/username is missing or empty/)
        expect(result[:status]).to eq(:internal_server_error)
      end

      it 'returns a structured error when password is missing' do
        allow(Settings.gclaws).to receive(:accreditation_xlsx).and_return(
          OpenStruct.new(
            url: test_url,
            username: test_username,
            password: nil
          )
        )

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX configuration_error error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to match(/GCLAWS XLSX configuration error/)
        expect(result[:error]).to match(/password is missing or empty/)
        expect(result[:status]).to eq(:internal_server_error)
      end
    end

    context 'when the request is successful' do
      before do
        allow(Open3).to receive(:capture3) do |*command|
          # Verify curl command structure
          expect(command).to include('curl')
          expect(command).to include('--ntlm')
          expect(command).to include('--max-time')
          expect(command).to include('120')
          expect(command).to include('--connect-timeout')
          expect(command).to include('30')

          # Verify -w flag for HTTP code and content-type output
          w_index = command.index('-w')
          expect(w_index).not_to be_nil
          expect(command[w_index + 1]).to eq('%<http_code>s\n%<content_type>s')

          # Write mock XLSX content to output file
          output_index = command.index('-o')
          output_file = command[output_index + 1]
          File.write(output_file, xlsx_binary_content)

          # Return successful curl output: HTTP status + content-type
          stdout = "200\n#{xlsx_content_type}"
          stderr = ''
          status = double('Process::Status', success?: true, exitstatus: 0)

          [stdout, stderr, status]
        end
      end

      it 'yields success result with file path' do
        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(result[:success]).to be true
        expect(result[:file_path]).to be_a(String)
        expect(result[:error]).to be_nil
      end

      it 'allows reading the file content within the block' do
        content_read = nil
        subject.download_accreditation_xlsx do |result|
          content_read = File.read(result[:file_path]) if result[:success]
        end

        expect(content_read).to eq(xlsx_binary_content)
      end

      it 'handles content-type with charset parameter' do
        allow(Open3).to receive(:capture3) do |*command|
          output_index = command.index('-o')
          output_file = command[output_index + 1]
          File.write(output_file, xlsx_binary_content)

          stdout = "200\n#{xlsx_content_type}; charset=utf-8"
          stderr = ''
          status = double('Process::Status', success?: true, exitstatus: 0)

          [stdout, stderr, status]
        end

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(result[:success]).to be true
      end

      it 'cleans up tempfiles after block completes' do
        file_path = nil

        # Capture paths before they're deleted
        allow(Tempfile).to receive(:new).and_wrap_original do |method, *args|
          tempfile = method.call(*args)
          file_path = tempfile.path if args[0].is_a?(Array) && args[0][0] == 'gclaws_accreditation'
          tempfile
        end

        subject.download_accreditation_xlsx do |result|
          # Files should exist during block
          expect(File.exist?(result[:file_path])).to be true if result[:success]
        end

        # Files should be deleted after block
        expect(File.exist?(file_path)).to be false if file_path
      end
    end

    context 'when content-type is invalid' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'returns an error for text/html content-type' do
        allow(Open3).to receive(:capture3) do |*command|
          output_index = command.index('-o')
          output_file = command[output_index + 1]
          File.write(output_file, '<html>Error page</html>')

          stdout = "200\ntext/html"
          stderr = ''
          status = double('Process::Status', success?: true, exitstatus: 0)

          [stdout, stderr, status]
        end

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX invalid_content_type error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid content type: text/html')
        expect(result[:status]).to eq(:unprocessable_entity)
      end

      it 'returns an error for application/json content-type' do
        allow(Open3).to receive(:capture3) do |*command|
          output_index = command.index('-o')
          output_file = command[output_index + 1]
          File.write(output_file, '{"error": "not xlsx"}')

          stdout = "200\napplication/json"
          stderr = ''
          status = double('Process::Status', success?: true, exitstatus: 0)

          [stdout, stderr, status]
        end

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX invalid_content_type error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid content type: application/json')
        expect(result[:status]).to eq(:unprocessable_entity)
      end

      it 'returns an error when content-type is empty' do
        allow(Open3).to receive(:capture3) do |*command|
          output_index = command.index('-o')
          output_file = command[output_index + 1]
          File.write(output_file, xlsx_binary_content)

          stdout = "200\n"
          stderr = ''
          status = double('Process::Status', success?: true, exitstatus: 0)

          [stdout, stderr, status]
        end

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX invalid_content_type error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid content type: ')
        expect(result[:status]).to eq(:unprocessable_entity)
      end
    end

    context 'when the request is unauthorized (401)' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'returns an unauthorized error' do
        allow(Open3).to receive(:capture3) do
          stdout = "401\ntext/html"
          stderr = ''
          status = double('Process::Status', success?: true, exitstatus: 0)

          [stdout, stderr, status]
        end

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX unauthorized error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX unauthorized')
        expect(result[:status]).to eq(:unauthorized)
      end
    end

    context 'when the server returns an error status' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'returns a bad gateway error for 500 status' do
        allow(Open3).to receive(:capture3) do
          stdout = "500\ntext/html"
          stderr = ''
          status = double('Process::Status', success?: true, exitstatus: 0)

          [stdout, stderr, status]
        end

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX http_error error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX request failed with status 500')
        expect(result[:status]).to eq(:bad_gateway)
      end

      it 'returns a bad gateway error for 503 status' do
        allow(Open3).to receive(:capture3) do
          stdout = "503\ntext/html"
          stderr = ''
          status = double('Process::Status', success?: true, exitstatus: 0)

          [stdout, stderr, status]
        end

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX http_error error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX request failed with status 503')
        expect(result[:status]).to eq(:bad_gateway)
      end
    end

    context 'when the connection times out' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'returns a timeout error (curl exit code 28)' do
        allow(Open3).to receive(:capture3) do
          stdout = ''
          stderr = 'curl: (28) Operation timed out'
          status = double('Process::Status', success?: false, exitstatus: 28)

          [stdout, stderr, status]
        end

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX timeout error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX download timed out')
        expect(result[:status]).to eq(:request_timeout)
      end
    end

    context 'when the connection fails' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'returns a service unavailable error for connection refused (exit code 7)' do
        allow(Open3).to receive(:capture3) do
          stdout = ''
          stderr = 'curl: (7) Failed to connect to host'
          status = double('Process::Status', success?: false, exitstatus: 7)

          [stdout, stderr, status]
        end

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX connection_failed error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX service unavailable')
        expect(result[:status]).to eq(:service_unavailable)
      end

      it 'returns a service unavailable error for resolve error (exit code 6)' do
        allow(Open3).to receive(:capture3) do
          stdout = ''
          stderr = 'curl: (6) Could not resolve host'
          status = double('Process::Status', success?: false, exitstatus: 6)

          [stdout, stderr, status]
        end

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX connection_failed error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX service unavailable')
        expect(result[:status]).to eq(:service_unavailable)
      end
    end

    context 'when curl returns HTTP error with -f flag (exit code 22)' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'returns unauthorized error when stderr contains 401' do
        allow(Open3).to receive(:capture3) do
          stdout = ''
          stderr = 'curl: (22) The requested URL returned error: 401'
          status = double('Process::Status', success?: false, exitstatus: 22)

          [stdout, stderr, status]
        end

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX unauthorized error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('GCLAWS XLSX unauthorized')
        expect(result[:status]).to eq(:unauthorized)
      end

      it 'returns http_error for other HTTP errors' do
        allow(Open3).to receive(:capture3) do
          stdout = ''
          stderr = 'curl: (22) The requested URL returned error: 500'
          status = double('Process::Status', success?: false, exitstatus: 22)

          [stdout, stderr, status]
        end

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX http_error error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to match(/GCLAWS XLSX HTTP error/)
        expect(result[:status]).to eq(:bad_gateway)
      end
    end

    context 'when an unexpected curl error occurs' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'returns an internal server error' do
        allow(Open3).to receive(:capture3) do
          stdout = ''
          stderr = 'curl: (35) SSL connect error'
          status = double('Process::Status', success?: false, exitstatus: 35)

          [stdout, stderr, status]
        end

        result = nil
        subject.download_accreditation_xlsx do |r|
          result = r
        end

        expect(Rails.logger).to have_received(:error).with(
          /#{error_log_prefix} GCLAWS XLSX unexpected error/
        )

        expect(result[:success]).to be false
        expect(result[:error]).to match(/GCLAWS XLSX unexpected curl error/)
        expect(result[:status]).to eq(:internal_server_error)
      end
    end

    context 'tempfile cleanup' do
      it 'cleans up tempfiles even when an error occurs' do
        file_path = nil

        allow(Tempfile).to receive(:new).and_wrap_original do |method, *args|
          tempfile = method.call(*args)
          file_path = tempfile.path if args[0].is_a?(Array) && args[0][0] == 'gclaws_accreditation'
          tempfile
        end

        allow(Open3).to receive(:capture3) do
          stdout = ''
          stderr = 'curl: (28) Operation timed out'
          status = double('Process::Status', success?: false, exitstatus: 28)

          [stdout, stderr, status]
        end

        allow(Rails.logger).to receive(:error)

        subject.download_accreditation_xlsx do |result|
          # Block receives error result
          expect(result[:success]).to be false
        end

        # File should still be deleted after error
        expect(File.exist?(file_path)).to be false if file_path
      end

      it 'cleans up tempfiles even when block raises an exception' do
        file_path = nil

        allow(Tempfile).to receive(:new).and_wrap_original do |method, *args|
          tempfile = method.call(*args)
          file_path = tempfile.path if args[0].is_a?(Array) && args[0][0] == 'gclaws_accreditation'
          tempfile
        end

        allow(Open3).to receive(:capture3) do |*command|
          output_index = command.index('-o')
          output_file = command[output_index + 1]
          File.write(output_file, xlsx_binary_content)

          stdout = "200\n#{xlsx_content_type}"
          stderr = ''
          status = double('Process::Status', success?: true, exitstatus: 0)

          [stdout, stderr, status]
        end

        expect do
          subject.download_accreditation_xlsx do |_result|
            raise StandardError, 'Block error'
          end
        end.to raise_error(StandardError, 'Block error')

        # File should still be deleted after exception
        expect(File.exist?(file_path)).to be false if file_path
      end
    end
  end

  describe '.notify_slack_error' do
    context 'in production environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
        allow(Rails.logger).to receive(:error)
      end

      it 'sends a Slack notification' do
        slack_client = instance_double(SlackNotify::Client)
        allow(SlackNotify::Client).to receive(:new).and_return(slack_client)
        allow(slack_client).to receive(:notify)

        allow(Open3).to receive(:capture3) do
          stdout = "401\ntext/html"
          stderr = ''
          status = double('Process::Status', success?: true, exitstatus: 0)

          [stdout, stderr, status]
        end

        subject.download_accreditation_xlsx do |result|
          # noop
        end

        expect(slack_client).to have_received(:notify).with(
          a_string_including('GCLAWS XLSX Download Error Alert')
        )
      end
    end

    context 'in non-production environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('staging')
        allow(Rails.logger).to receive(:error)
      end

      it 'does not send a Slack notification' do
        slack_client = instance_double(SlackNotify::Client)
        allow(SlackNotify::Client).to receive(:new).and_return(slack_client)
        allow(slack_client).to receive(:notify)

        allow(Open3).to receive(:capture3) do
          stdout = "401\ntext/html"
          stderr = ''
          status = double('Process::Status', success?: true, exitstatus: 0)

          [stdout, stderr, status]
        end

        subject.download_accreditation_xlsx do |result|
          # noop
        end

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

        allow(Open3).to receive(:capture3) do
          stdout = "401\ntext/html"
          stderr = ''
          status = double('Process::Status', success?: true, exitstatus: 0)

          [stdout, stderr, status]
        end

        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} GCLAWS XLSX unauthorized error/
        )
        expect(Rails.logger).to receive(:error).with(
          /#{error_log_prefix} Failed to send Slack notification/
        )

        # Should not raise, just log
        expect do
          subject.download_accreditation_xlsx do |result|
            # noop
          end
        end.not_to raise_error
      end
    end
  end
end
