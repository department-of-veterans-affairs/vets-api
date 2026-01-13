# frozen_string_literal: true

require 'rails_helper'
require 'form21p530a/monitor'

RSpec.describe Form21p530a::Monitor do
  subject(:monitor) { described_class.new }

  let(:stats_key) { described_class::STATS_KEY }
  let(:form_id) { described_class::FORM_ID }

  describe '#track_request_validation_error' do
    let(:request) do
      instance_double(
        Rack::Request,
        path: '/v0/form21p530a',
        request_method: 'POST',
        env: { 'SOURCE_APP' => '21p-530a-interment-allowance' }
      )
    end

    context 'with pattern mismatch error' do
      let(:error) do
        instance_double(
          Committee::InvalidRequest,
          message: '#/properties/veteranInformation/properties/ssn pattern ^\\d{9}$ does not match value'
        )
      end

      it 'increments StatsD metric with correct tags' do
        expect(StatsD).to receive(:increment).with(
          "#{stats_key}.validation_error",
          hash_including(tags: array_including('service:form21p530a'))
        )

        monitor.track_request_validation_error(error:, request:)
      end

      it 'logs validation error with warn level' do
        expect(Rails.logger).to receive(:warn).with(
          "Form21p530a::Monitor #{form_id} Committee validation failed",
          hash_including(
            context: hash_including(
              form_id:,
              path: '/v0/form21p530a',
              method: 'POST',
              source_app: '21p-530a-interment-allowance',
              error_type: 'pattern_mismatch',
              data_pointer: kind_of(String)
            )
          )
        )

        monitor.track_request_validation_error(error:, request:)
      end

      it 'extracts error_type as pattern_mismatch' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:error_type]).to eq('pattern_mismatch')
        end

        monitor.track_request_validation_error(error:, request:)
      end

      it 'does not include PII in logs' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |message, payload|
          # Ensure no SSN patterns in logged data
          expect(message).not_to match(/\d{3}-\d{2}-\d{4}/)
          expect(message).not_to match(/\d{9}/)
          expect(payload[:context].to_s).not_to match(/\d{3}-\d{2}-\d{4}/)
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end

    context 'with missing required field error' do
      let(:error) do
        instance_double(
          Committee::InvalidRequest,
          message: 'object at `/veteranInformation` is missing required properties: fullName'
        )
      end

      it 'extracts error_type as missing_required' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:error_type]).to eq('missing_required')
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end

    context 'with type mismatch error' do
      let(:error) do
        instance_double(
          Committee::InvalidRequest,
          message: 'expected string, got integer'
        )
      end

      it 'extracts error_type as type_mismatch' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:error_type]).to eq('type_mismatch')
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end

    context 'with invalid enum error' do
      let(:error) do
        instance_double(
          Committee::InvalidRequest,
          message: '"XX" is not a member of enum'
        )
      end

      it 'extracts error_type as invalid_enum' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:error_type]).to eq('invalid_enum')
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end

    context 'with length validation error' do
      let(:error) do
        instance_double(
          Committee::InvalidRequest,
          message: 'string length is greater than maxLength: 50'
        )
      end

      it 'extracts error_type as invalid_length' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:error_type]).to eq('invalid_length')
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end

    context 'with unknown error type' do
      let(:error) do
        instance_double(
          Committee::InvalidRequest,
          message: 'Some other validation error'
        )
      end

      it 'extracts error_type as validation_error' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:error_type]).to eq('validation_error')
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end

    context 'when source app is not provided' do
      let(:request) do
        instance_double(
          Rack::Request,
          path: '/v0/form21p530a',
          request_method: 'POST',
          env: {}
        )
      end
      let(:error) do
        instance_double(
          Committee::InvalidRequest,
          message: 'validation error'
        )
      end

      it 'defaults source_app to unknown' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:source_app]).to eq('unknown')
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end

    context 'data pointer extraction' do
      let(:request) do
        instance_double(
          Rack::Request,
          path: '/v0/form21p530a',
          request_method: 'POST',
          env: {}
        )
      end

      it 'extracts field path from schema reference' do
        error = instance_double(
          Committee::InvalidRequest,
          message: '#/properties/veteranInformation/properties/fullName/properties/first required'
        )

        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          # Path is cleaned up to remove 'properties/' but keeps relative structure
          expect(payload[:context][:data_pointer]).to match(%r{veteranInformation/fullName/first})
        end

        monitor.track_request_validation_error(error:, request:)
      end

      it 'handles messages without field path' do
        error = instance_double(
          Committee::InvalidRequest,
          message: 'validation error with no path'
        )

        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:data_pointer]).to eq('unknown')
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end
  end
end
