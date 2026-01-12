# frozen_string_literal: true

require 'rails_helper'
require 'vye/dgib/service'
require 'vye/dgib/response'

RSpec.describe Vye::DGIB::Service do
  include ActiveSupport::Testing::TimeHelpers
  let(:user) { create(:user, :loa3) }
  let(:service) { described_class.new(user) }

  describe '#claimant_lookup' do
    let(:ssn) { '123-45-6789' }
    let(:response_body) { JSON.parse(File.read('modules/vye/spec/fixtures/claimant_lookup_response.json')) }

    before { allow(service).to receive(:perform).and_return(double('response', status: 200, body: response_body)) }

    context 'when successful' do
      it 'returns a status of 200' do
        travel_to Time.zone.local(2022, 2, 9, 12) do
          response = service.claimant_lookup(ssn)

          expect(response.status).to eq(200)
          expect(response.ok?).to be(true)
        end
      end

      context 'when claimant ID zero' do
        let(:zero_id_metric) { "#{described_class::STATSD_KEY_PREFIX}.claimant_lookup_id_zero" }
        let(:raw_response) { instance_double(Faraday::Response, status: 200, body: { 'claimant_id' => 0 }) }

        before do
          allow(service).to receive(:perform).and_return(raw_response)
          allow(StatsD).to receive(:increment)
        end

        it 'increments custom metric' do
          travel_to Time.zone.local(2022, 2, 9, 12) do
            service.claimant_lookup(ssn)
            expect(StatsD).to have_received(:increment).with(zero_id_metric)
          end
        end
      end
    end

    context 'when unsuccessful' do
      let(:error_message) { 'FAILED' }
      let(:backend_error) { StandardError.new(error_message) }
      let(:method_name) { :claimant_lookup }

      before do
        allow(service).to receive(:perform).and_raise(backend_error)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error message with context' do
        travel_to Time.zone.local(2022, 2, 9, 12) do
          expect { service.claimant_lookup(ssn) }.to raise_error(StandardError)

          expect(Rails.logger).to have_received(:error).with(
            'DGI/VYE service error',
            hash_including(
              service: 'DGI/VYE',
              method: method_name,
              error_class: backend_error.class.name,
              error_status: backend_error.try(:status),
              timestamp: Time.current.iso8601
            ),
            hash_including(:backtrace)
          )
        end
      end
    end
  end

  context 'with headers and options' do
    let(:mock_token) { 'mock_bearer_token_12345' }
    let(:headers) { { Authorization: "Bearer #{mock_token}" } }
    let(:options) { { timeout: 60 } }

    before { allow(Vye::DGIB::AuthenticationTokenService).to receive(:call).and_return(mock_token) }

    describe '#get_claimant_status' do
      let(:claimant_id) { 600_010_259 }
      let(:response_body) { JSON.parse(File.read('modules/vye/spec/fixtures/claimant_response.json')) }

      before do
        allow(service)
          .to receive(:perform)
          .with(:get, "verifications/vye/#{claimant_id}/status", {}, headers, options)
          .and_return(double('response', status: 200, body: response_body))
      end

      context 'when successful' do
        it 'returns a status of 200' do
          travel_to Time.zone.local(2022, 2, 9, 12) do
            response = service.get_claimant_status(claimant_id)
            expect(response.status).to eq(200)
            expect(response.ok?).to be(true)
          end
        end
      end

      context 'when unsuccessful' do
        let(:error_message) { 'FAILED' }
        let(:backend_error) { StandardError.new(error_message) }
        let(:method_name) { :get_claimant_status }

        before do
          allow(service).to receive(:perform).and_raise(backend_error)
          allow(Rails.logger).to receive(:error)
        end

        it 'logs error message with context' do
          travel_to Time.zone.local(2022, 2, 9, 12) do
            expect { service.get_claimant_status(claimant_id) }.to raise_error(StandardError)

            expect(Rails.logger).to have_received(:error).with(
              'DGI/VYE service error',
              hash_including(
                service: 'DGI/VYE',
                method: method_name,
                error_class: backend_error.class.name,
                error_status: backend_error.try(:status),
                timestamp: Time.current.iso8601
              ),
              hash_including(:backtrace)
            )
          end
        end
      end
    end

    describe '#get_verification_record' do
      let(:claimant_id) { 600_010_259 }
      let(:response_body) { JSON.parse(File.read('modules/vye/spec/fixtures/claimant_response.json')) }

      before do
        allow(service)
          .to receive(:perform)
          .with(:get, "verifications/vye/#{claimant_id}/verification-record", {}, headers, options)
          .and_return(double('response', status: 200, body: response_body))
      end

      context 'when successful' do
        it 'returns a status of 200' do
          travel_to Time.zone.local(2022, 2, 9, 12) do
            response = service.get_verification_record(claimant_id)
            expect(response.status).to eq(200)
            expect(response.ok?).to be(true)
          end
        end
      end

      context 'when unsuccessful' do
        let(:error_message) { 'FAILED' }
        let(:backend_error) { StandardError.new(error_message) }
        let(:method_name) { :get_verification_record }

        before do
          allow(service).to receive(:perform).and_raise(backend_error)
          allow(Rails.logger).to receive(:error)
        end

        it 'logs error message with context' do
          travel_to Time.zone.local(2022, 2, 9, 12) do
            expect { service.get_verification_record(claimant_id) }.to raise_error(StandardError)

            expect(Rails.logger).to have_received(:error).with(
              'DGI/VYE service error',
              hash_including(
                service: 'DGI/VYE',
                method: method_name,
                error_class: backend_error.class.name,
                error_status: backend_error.try(:status),
                timestamp: Time.current.iso8601
              ),
              hash_including(:backtrace)
            )
          end
        end
      end
    end

    describe '#get_verify_claimant' do
      let(:claimant_id) { 600_010_259 }
      let(:verified_period_begin_date) { '2022-01-01' }
      let(:verified_period_end_date) { '2022-01-31' }
      let(:verified_through_date) { '2022-01-31' }
      let(:verification_method) { 'Initial' }
      let(:response_type) { '200' }
      let(:response_body) { JSON.parse(File.read('modules/vye/spec/fixtures/claimant_lookup_response.json')) }
      let(:params) do
        ActionController::Parameters.new(
          {
            claimant_id:,
            verified_period_begin_date:,
            verified_period_end_date:,
            verified_through_date:,
            verification_method:,
            app_communication: { response_type: }
          }
        )
      end

      before do
        allow(service).to receive(:perform)
          .with(
            :post,
            'verifications/vye/verify',
            service.camelize_keys_for_java_service(params).to_json,
            headers,
            options
          )
          .and_return(double('response', status: 200, body: response_body))
      end

      context 'when successful' do
        it 'returns a status of 200' do
          travel_to Time.zone.local(2022, 2, 9, 12) do
            response =
              service
              .verify_claimant(
                claimant_id,
                verified_period_begin_date,
                verified_period_end_date,
                verified_through_date,
                verification_method,
                response_type
              )

            expect(response.status).to eq(200)
            expect(response.ok?).to be(true)
          end
        end
      end

      context 'when unsuccessful' do
        let(:error_message) { 'FAILED' }
        let(:backend_error) { StandardError.new(error_message) }
        let(:method_name) { :verify_claimant }

        before do
          allow(service).to receive(:perform).and_raise(backend_error)
          allow(Rails.logger).to receive(:error)
        end

        it 'logs error message with context' do
          travel_to Time.zone.local(2022, 2, 9, 12) do
            expect do
              service.verify_claimant(claimant_id,
                                      verified_period_begin_date,
                                      verified_period_end_date,
                                      verified_through_date,
                                      verification_method,
                                      response_type)
            end.to raise_error(StandardError)

            expect(Rails.logger).to have_received(:error).with(
              'DGI/VYE service error',
              hash_including(
                service: 'DGI/VYE',
                method: method_name,
                error_class: backend_error.class.name,
                error_status: backend_error.try(:status),
                timestamp: Time.current.iso8601
              ),
              hash_including(:backtrace)
            )
          end
        end
      end
    end
  end
end
