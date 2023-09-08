# frozen_string_literal: true

require 'rails_helper'
require 'mobile_application_platform/sign_up/service'

describe MobileApplicationPlatform::SignUp::Service do
  let(:icn) { '10101V964144' }
  let(:log_prefix) { '[MobileApplicationPlatform][SignUp][Service]' }

  describe '#status' do
    subject { described_class.new.status(icn:) }

    context 'when an issue occurs with the client request' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) do
        "#{log_prefix} status failed, client error, status: #{status}, " \
          "description: #{description}, icn: #{icn}"
      end
      let(:status) { 'some-status' }
      let(:description) { 'some-description' }
      let(:raised_error) { Common::Client::Errors::ClientError.new(nil, status, { error_description: description }) }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(raised_error)
      end

      it 'raises a client error with expected message' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when client response is malformed' do
      let(:expected_error) { NoMethodError }
      let(:expected_error_message) { "#{log_prefix} status failed, response unknown, icn: #{icn}" }
      let(:status) { 'some-status' }
      let(:description) { 'some-description' }
      let(:empty_response) { nil }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_return(empty_response)
      end

      it 'raises an unknown response error with expected message' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when response is successful' do
      let(:expected_log_message) { "#{log_prefix} status success, icn: #{icn}" }
      let(:expected_response_hash) do
        {
          agreement_signed: true,
          opt_out: false,
          cerner_provisioned: false,
          bypass_eligible: false
        }
      end

      it 'logs a token success message',
         vcr: { cassette_name: 'mobile_application_platform/sign_up_service_200_responses' } do
        expect(Rails.logger).to receive(:info).with(expected_log_message)
        subject
      end

      it 'returns response hash with expected fields',
         vcr: { cassette_name: 'mobile_application_platform/sign_up_service_200_responses' } do
        expect(subject).to eq(expected_response_hash)
      end
    end
  end

  describe '#agreements_accept' do
    subject { described_class.new.agreements_accept(icn:) }

    context 'when an issue occurs with the client request' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) do
        "#{log_prefix} agreements accept failed, client error, status: #{status}, " \
          "description: #{description}, icn: #{icn}"
      end
      let(:status) { 'some-status' }
      let(:description) { 'some-description' }
      let(:raised_error) { Common::Client::Errors::ClientError.new(nil, status, { error_description: description }) }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(raised_error)
      end

      it 'raises a client error with expected message' do
        VCR.use_cassette('mobile_application_platform/security_token_service_200_response') do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    context 'when response is not successful' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) do
        "#{log_prefix} agreements accept failed, client error, status: #{status}, " \
          "description: , icn: #{icn}"
      end
      let(:status) { 401 }

      it 'raises a client error with expected message' do
        VCR.use_cassette('mobile_application_platform/security_token_service_200_response') do
          VCR.use_cassette('mobile_application_platform/sign_up_service_authentication_failure_responses') do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end
      end
    end

    context 'when response is successful' do
      let(:expected_log_message) { "#{log_prefix} agreements accept success, icn: #{icn}" }

      before { allow(Rails.logger).to receive(:info) }

      it 'logs an agreements accept success message' do
        VCR.use_cassette('mobile_application_platform/security_token_service_200_response') do
          VCR.use_cassette('mobile_application_platform/sign_up_service_200_responses') do
            expect(Rails.logger).to receive(:info).with(expected_log_message)
            subject
          end
        end
      end
    end
  end

  describe '#agreements_decline' do
    subject { described_class.new.agreements_decline(icn:) }

    context 'when an issue occurs with the client request' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) do
        "#{log_prefix} agreements decline failed, client error, status: #{status}, " \
          "description: #{description}, icn: #{icn}"
      end
      let(:status) { 'some-status' }
      let(:description) { 'some-description' }
      let(:raised_error) { Common::Client::Errors::ClientError.new(nil, status, { error_description: description }) }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(raised_error)
      end

      it 'raises a client error with expected message' do
        VCR.use_cassette('mobile_application_platform/security_token_service_200_response') do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    context 'when response is not successful' do
      let(:expected_log_message) { "#{log_prefix} agreements decline failed, icn: #{icn}" }
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) do
        "#{log_prefix} agreements decline failed, client error, status: #{status}, " \
          "description: , icn: #{icn}"
      end
      let(:status) { 401 }

      before { allow(Rails.logger).to receive(:info) }

      it 'raises a client error with expected message' do
        VCR.use_cassette('mobile_application_platform/security_token_service_200_response') do
          VCR.use_cassette('mobile_application_platform/sign_up_service_authentication_failure_responses') do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end
      end
    end

    context 'when response is successful' do
      let(:expected_log_message) { "#{log_prefix} agreements decline success, icn: #{icn}" }

      before { allow(Rails.logger).to receive(:info) }

      it 'logs an agreements decline success message' do
        VCR.use_cassette('mobile_application_platform/security_token_service_200_response') do
          VCR.use_cassette('mobile_application_platform/sign_up_service_200_responses') do
            expect(Rails.logger).to receive(:info).with(expected_log_message).once
            subject
          end
        end
      end
    end
  end

  describe '#update_provisioning' do
    subject { described_class.new.update_provisioning(icn:, first_name:, last_name:, mpi_gcids:) }

    let(:icn) { '1012667145V762142' }
    let(:first_name) { 'Tamara' }
    let(:last_name) { 'Ellis' }
    let(:mpi_gcids) do
      '1012667145V762142^NI^200M^USVHA^P|1005490754^NI^200DOD^USDOD^A|600043201^PI^200CORP^USVBA^A|' \
        '123456^PI^200ESR^USVHA^A|123456^PI^648^USVHA^A|123456^PI^200BRLS^USVBA^A'
    end

    context 'when an issue occurs with the client request' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) do
        "#{log_prefix} update provisioning failed, client error, status: #{status}, " \
          "description: #{description}, icn: #{icn}"
      end
      let(:status) { 'some-status' }
      let(:description) { 'some-description' }
      let(:raised_error) { Common::Client::Errors::ClientError.new(nil, status, { error_description: description }) }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(raised_error)
      end

      it 'raises a client error with expected message' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when client response is malformed' do
      let(:expected_error) { NoMethodError }
      let(:expected_error_message) { "#{log_prefix} update provisioning failed, response unknown, icn: #{icn}" }
      let(:status) { 'some-status' }
      let(:description) { 'some-description' }
      let(:empty_response) { nil }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_return(empty_response)
      end

      it 'raises an unknown response error with expected message' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when response is successful' do
      let(:expected_log_message) { "#{log_prefix} update provisioning success, icn: #{icn}" }
      let(:expected_response_hash) do
        {
          agreement_signed: true,
          opt_out: false,
          cerner_provisioned: false,
          bypass_eligible: false
        }
      end

      it 'logs a token success message',
         vcr: { cassette_name: 'mobile_application_platform/sign_up_service_200_responses' } do
        expect(Rails.logger).to receive(:info).with(expected_log_message)
        subject
      end

      it 'returns response hash with expected fields',
         vcr: { cassette_name: 'mobile_application_platform/sign_up_service_200_responses' } do
        expect(subject).to eq(expected_response_hash)
      end
    end
  end
end
