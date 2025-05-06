# frozen_string_literal: true

require 'rails_helper'
require 'map/sign_up/service'

describe MAP::SignUp::Service do
  let(:icn) { '10101V964144' }
  let(:signature_name) { 'some-signature-name' }
  let(:version) { 'v1' }
  let(:log_prefix) { '[MAP][SignUp][Service]' }

  shared_examples 'error response' do
    let(:context) do
      {
        id: expected_error_id,
        code: expected_error_status,
        error_code: expected_error_code,
        message: expected_error_message,
        trace_id: expected_error_trace_id
      }.compact
    end
    let(:expected_message) do
      "#{log_prefix} #{action} failed, client error, status: #{expected_error_status}, icn: #{icn}, context: #{context}"
    end
    let(:expected_error) { Common::Client::Errors::ClientError }

    it 'raises a client error with expected message' do
      VCR.use_cassette('map/security_token_service_200_response') do
        VCR.use_cassette(vcr_cassette) do
          expect { subject }.to raise_error(expected_error, expected_message)
        end
      end
    end
  end

  shared_examples 'malformed response' do
    it 'logs the expected error message and raises a parsing error' do
      VCR.use_cassette('map/security_token_service_200_response') do
        VCR.use_cassette('map/sign_up_service_200_malformed_responses') do
          expect(Rails.logger).to receive(:error).with(expected_log_message, { icn: })
          expect { subject }.to raise_error(Common::Client::Errors::ParsingError)
        end
      end
    end
  end

  describe '#status' do
    subject { described_class.new.status(icn:) }

    context 'when response is not successful with a 400 error' do
      let(:vcr_cassette) { 'map/sign_up_service_400_responses' }
      let(:action) { 'status' }
      let(:expected_error_id) { '381e5926-12f4-48f7-9ca5-2ed2f631daab' }
      let(:expected_error_code) { 14 }
      let(:expected_error_status) { 400 }
      let(:expected_error_message) { 'ICN has invalid format' }
      let(:expected_error_trace_id) { nil }

      it_behaves_like 'error response'
    end

    context 'when there is a parsing error' do
      let(:expected_log_message) { "#{log_prefix} status response parsing error" }

      it_behaves_like 'malformed response'
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
         vcr: { cassette_name: 'map/sign_up_service_200_responses' } do
        expect(Rails.logger).to receive(:info).with(expected_log_message)
        subject
      end

      it 'returns response hash with expected fields',
         vcr: { cassette_name: 'map/sign_up_service_200_responses' } do
        expect(subject).to eq(expected_response_hash)
      end
    end
  end

  describe '#agreements_accept' do
    subject { described_class.new.agreements_accept(icn:, signature_name:, version:) }

    context 'when response is not successful with a 400 error' do
      let(:vcr_cassette) { 'map/sign_up_service_400_responses' }
      let(:action) { 'agreements accept' }
      let(:expected_error_id) { 'df5decee-8161-4c30-af74-7e030d2048e5' }
      let(:expected_error_code) { 11 }
      let(:expected_error_status) { 400 }
      let(:expected_error_message) { 'Missing EDIPI Identifier' }
      let(:expected_error_trace_id) { nil }

      it_behaves_like 'error response'
    end

    context 'when response is not successful with a 401 error' do
      let(:vcr_cassette) { 'map/sign_up_service_401_responses' }
      let(:action) { 'agreements accept' }
      let(:expected_error_id) { nil }
      let(:expected_error_code) { nil }
      let(:expected_error_status) { 401 }
      let(:expected_error_message) { 'Unauthenticated access is not permitted.' }
      let(:expected_error_trace_id) { '3dd9f18b1edbf391c05868af8de6148a' }

      it_behaves_like 'error response'
    end

    context 'when there is a parsing error' do
      let(:expected_log_message) { "#{log_prefix} agreements accept response parsing error" }

      it_behaves_like 'malformed response'
    end

    context 'when response is successful' do
      let(:expected_log_message) { "#{log_prefix} agreements accept success, icn: #{icn}" }

      before do
        Timecop.freeze(Time.zone.local(2024, 9, 1, 12, 0, 0))
        allow(Rails.logger).to receive(:info)
      end

      after { Timecop.return }

      it 'logs an agreements accept success message' do
        VCR.use_cassette('map/security_token_service_200_response') do
          VCR.use_cassette('map/sign_up_service_200_responses', match_requests_on: %i[method path body]) do
            expect(Rails.logger).to receive(:info).with(expected_log_message)
            subject
          end
        end
      end
    end
  end

  describe '#agreements_decline' do
    subject { described_class.new.agreements_decline(icn:) }

    context 'when response is not successful with a 400 error' do
      let(:vcr_cassette) { 'map/sign_up_service_400_responses' }
      let(:action) { 'agreements decline' }
      let(:expected_error_id) { '892994ef-7e92-42fb-b0c2-98fa396eec4e' }
      let(:expected_error_code) { 15 }
      let(:expected_error_status) { 400 }
      let(:expected_error_message) { 'No existing agreement found for Veteran' }
      let(:expected_error_trace_id) { nil }

      it_behaves_like 'error response'
    end

    context 'when response is not successful with a 401 error' do
      let(:vcr_cassette) { 'map/sign_up_service_401_responses' }
      let(:action) { 'agreements decline' }
      let(:expected_error_id) { nil }
      let(:expected_error_code) { nil }
      let(:expected_error_status) { 401 }
      let(:expected_error_message) { 'Unauthenticated access is not permitted.' }
      let(:expected_error_trace_id) { '9ab25637428a6eb92f4713ce15475939' }

      it_behaves_like 'error response'
    end

    context 'when there is a parsing error' do
      let(:expected_log_message) { "#{log_prefix} agreements decline response parsing error" }

      it_behaves_like 'malformed response'
    end

    context 'when response is successful' do
      let(:expected_log_message) { "#{log_prefix} agreements decline success, icn: #{icn}" }

      before { allow(Rails.logger).to receive(:info) }

      it 'logs an agreements decline success message' do
        VCR.use_cassette('map/security_token_service_200_response') do
          VCR.use_cassette('map/sign_up_service_200_responses') do
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

    context 'when response is not successful with a 400 error' do
      let(:vcr_cassette) { 'map/sign_up_service_400_responses' }
      let(:action) { 'update provisioning' }
      let(:expected_error_id) { nil }
      let(:expected_error_code) { nil }
      let(:expected_error_trace_id) { 'ef7bcc0708137692610a0a5f66746afc' }
      let(:expected_error_status) { 400 }
      let(:expected_error_message) { 'X-VAMF-API-KEY not found or invalid.' }

      it_behaves_like 'error response'
    end

    context 'when response is successful' do
      let(:expected_log_message) do
        "#{log_prefix} update provisioning success, icn: #{icn}, parsed_response: #{expected_response_hash}"
      end
      let(:expected_response_hash) do
        {
          agreement_signed: true,
          opt_out: false,
          cerner_provisioned: false,
          bypass_eligible: false
        }
      end

      it 'logs a token success message',
         vcr: { cassette_name: 'map/sign_up_service_200_responses' } do
        expect(Rails.logger).to receive(:info).with(expected_log_message)
        subject
      end

      it 'returns response hash with expected fields',
         vcr: { cassette_name: 'map/sign_up_service_200_responses' } do
        expect(subject).to eq(expected_response_hash)
      end
    end

    context 'when response is successful with 406' do
      let(:expected_log_message) do
        "#{log_prefix} update provisioning success, icn: #{icn}, parsed_response: #{expected_response_hash}"
      end
      let(:expected_response_hash) do
        {
          agreement_signed: true,
          opt_out: false,
          cerner_provisioned: false,
          bypass_eligible: false
        }
      end

      it 'logs a token success message',
         vcr: { cassette_name: 'map/sign_up_service_406_responses' } do
        expect(Rails.logger).to receive(:info).with(expected_log_message)
        subject
      end

      it 'returns response hash with expected fields',
         vcr: { cassette_name: 'map/sign_up_service_406_responses' } do
        expect(subject).to eq(expected_response_hash)
      end
    end

    context 'when response is successful with 412' do
      let(:expected_log_message) do
        "#{log_prefix} update provisioning success, icn: #{icn}, parsed_response: #{expected_response_hash}"
      end
      let(:expected_response_hash) do
        {
          agreement_signed: true,
          opt_out: false,
          cerner_provisioned: false,
          bypass_eligible: false
        }
      end

      it 'logs a token success message',
         vcr: { cassette_name: 'map/sign_up_service_412_responses' } do
        expect(Rails.logger).to receive(:info).with(expected_log_message)
        subject
      end

      it 'returns response hash with expected fields',
         vcr: { cassette_name: 'map/sign_up_service_412_responses' } do
        expect(subject).to eq(expected_response_hash)
      end
    end

    context 'when there is a parsing error' do
      let(:expected_log_message) { "#{log_prefix} update provisioning response parsing error" }

      it_behaves_like 'malformed response'
    end
  end
end
