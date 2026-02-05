# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/client'

RSpec.describe UnifiedHealthData::Client do
  subject(:client) { described_class.new }

  describe '#check_for_partial_failures!' do
    let(:success_body) do
      {
        'vista' => {
          'entry' => [
            { 'resource' => { 'resourceType' => 'AllergyIntolerance', 'id' => '123' } }
          ]
        },
        'oracle-health' => {
          'entry' => [
            { 'resource' => { 'resourceType' => 'AllergyIntolerance', 'id' => '456' } }
          ]
        }
      }
    end

    let(:partial_failure_body) do
      {
        'vista' => {
          'entry' => [
            { 'resource' => { 'resourceType' => 'AllergyIntolerance', 'id' => '123' } }
          ]
        },
        'oracle-health' => {
          'entry' => [
            {
              'resource' => {
                'resourceType' => 'OperationOutcome',
                'issue' => [
                  {
                    'severity' => 'error',
                    'code' => 'exception',
                    'diagnostics' => 'Exhausted retry attempts for Oracle Health - giving up'
                  }
                ]
              }
            }
          ]
        }
      }
    end

    context 'when SCDF returns success response' do
      let(:success_response) { Faraday::Response.new(body: success_body) }

      it 'does not raise an exception' do
        expect do
          client.send(:check_for_partial_failures!, success_response, '/uhd/v1/allergies?patientId=123')
        end.not_to raise_error
      end
    end

    context 'when SCDF returns OperationOutcome with error severity' do
      let(:partial_failure_response) { Faraday::Response.new(body: partial_failure_body) }

      before do
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)
      end

      it 'raises UpstreamPartialFailure exception' do
        expect do
          client.send(:check_for_partial_failures!, partial_failure_response, '/uhd/v1/allergies?patientId=123')
        end.to raise_error(Common::Exceptions::UpstreamPartialFailure)
      end

      it 'includes failed_sources in the exception' do
        client.send(:check_for_partial_failures!, partial_failure_response, '/uhd/v1/allergies?patientId=123')
      rescue Common::Exceptions::UpstreamPartialFailure => e
        expect(e.failed_sources).to eq(['oracle-health'])
      end

      it 'logs the partial failure' do
        begin
          client.send(:check_for_partial_failures!, partial_failure_response, '/uhd/v1/allergies?patientId=123')
        rescue Common::Exceptions::UpstreamPartialFailure
          # expected
        end

        expect(Rails.logger).to have_received(:warn).with(
          hash_including(
            message: 'UHD upstream source returned OperationOutcome error',
            failed_sources: ['oracle-health'],
            resource_type: 'allergies'
          )
        )
      end

      it 'increments StatsD counter' do
        begin
          client.send(:check_for_partial_failures!, partial_failure_response, '/uhd/v1/allergies?patientId=123')
        rescue Common::Exceptions::UpstreamPartialFailure
          # expected
        end

        expect(StatsD).to have_received(:increment).with(
          'api.uhd.partial_failure',
          tags: ['source:oracle-health', 'resource_type:allergies']
        )
      end
    end

    context 'when OperationOutcome has warning severity (not error)' do
      let(:warning_body) do
        {
          'vista' => { 'entry' => [] },
          'oracle-health' => {
            'entry' => [
              {
                'resource' => {
                  'resourceType' => 'OperationOutcome',
                  'issue' => [{ 'severity' => 'warning', 'code' => 'informational' }]
                }
              }
            ]
          }
        }
      end
      let(:warning_response) { Faraday::Response.new(body: warning_body) }

      it 'does not raise an exception' do
        expect do
          client.send(:check_for_partial_failures!, warning_response, '/uhd/v1/allergies?patientId=123')
        end.not_to raise_error
      end
    end

    context 'when response body is not a Hash (non-FHIR response)' do
      let(:array_response) { Faraday::Response.new(body: [{ 'success' => true }]) }

      it 'does not raise an exception' do
        expect do
          # refill endpoint returns array, not FHIR bundle
          client.send(:check_for_partial_failures!, array_response, '/uhd/v1/refill')
        end.not_to raise_error
      end
    end

    context 'when resource type is not a FHIR resource' do
      let(:response) { Faraday::Response.new(body: partial_failure_body) }

      it 'does not check for partial failures' do
        # "unknown" is not in FHIR_RESOURCE_TYPES, so no check happens
        expect do
          client.send(:check_for_partial_failures!, response, '/some/unknown/path')
        end.not_to raise_error
      end
    end
  end

  describe '#extract_resource_type' do
    it 'extracts allergies from path' do
      path = '/uhd/v1/allergies?patientId=123'
      expect(client.send(:extract_resource_type, path)).to eq('allergies')
    end

    it 'extracts labs from path' do
      path = '/uhd/v1/labs?patientId=123'
      expect(client.send(:extract_resource_type, path)).to eq('labs')
    end

    it 'extracts conditions from path' do
      path = '/uhd/v1/conditions?patientId=123'
      expect(client.send(:extract_resource_type, path)).to eq('conditions')
    end

    it 'extracts notes from path' do
      path = '/uhd/v1/notes?patientId=123'
      expect(client.send(:extract_resource_type, path)).to eq('notes')
    end

    it 'extracts vitals from path' do
      path = '/uhd/v1/vitals?patientId=123'
      expect(client.send(:extract_resource_type, path)).to eq('vitals')
    end

    it 'extracts immunizations from path' do
      path = '/uhd/v1/immunizations?patientId=123'
      expect(client.send(:extract_resource_type, path)).to eq('immunizations')
    end

    it 'extracts prescriptions from path' do
      path = '/uhd/v1/prescriptions?patientId=123'
      expect(client.send(:extract_resource_type, path)).to eq('prescriptions')
    end

    it 'extracts avs from path' do
      path = '/uhd/v1/avs?patientId=123&apptId=abc'
      expect(client.send(:extract_resource_type, path)).to eq('avs')
    end

    it 'extracts ccd from nested path' do
      path = '/uhd/v1/ccd/oracle-health?patientId=123'
      expect(client.send(:extract_resource_type, path)).to eq('ccd')
    end

    it 'returns unknown for unrecognized paths' do
      path = '/some/other/path'
      expect(client.send(:extract_resource_type, path)).to eq('unknown')
    end
  end

  describe '#fhir_resource?' do
    it 'returns true for FHIR resource types' do
      %w[allergies labs conditions notes vitals immunizations prescriptions avs ccd].each do |resource|
        expect(client.send(:fhir_resource?, resource)).to be true
      end
    end

    it 'returns false for non-FHIR resource types' do
      expect(client.send(:fhir_resource?, 'refill')).to be false
      expect(client.send(:fhir_resource?, 'unknown')).to be false
    end
  end
end
