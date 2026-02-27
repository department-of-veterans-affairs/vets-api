# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/client'

RSpec.describe UnifiedHealthData::Client do
  subject(:client) { described_class.new }

  describe '#check_for_operation_outcomes!' do
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
          client.send(:check_for_operation_outcomes!, success_response, '/uhd/v1/allergies?patientId=123')
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
          client.send(:check_for_operation_outcomes!, partial_failure_response, '/uhd/v1/allergies?patientId=123')
        end.to raise_error(Common::Exceptions::UpstreamPartialFailure)
      end

      it 'includes failed_sources in the exception' do
        client.send(:check_for_operation_outcomes!, partial_failure_response, '/uhd/v1/allergies?patientId=123')
      rescue Common::Exceptions::UpstreamPartialFailure => e
        expect(e.failed_sources).to eq(['oracle-health'])
      end

      it 'logs the partial failure' do
        begin
          client.send(:check_for_operation_outcomes!, partial_failure_response, '/uhd/v1/allergies?patientId=123')
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
          client.send(:check_for_operation_outcomes!, partial_failure_response, '/uhd/v1/allergies?patientId=123')
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

      before do
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)
      end

      it 'does not raise an exception' do
        expect do
          client.send(:check_for_operation_outcomes!, warning_response, '/uhd/v1/allergies?patientId=123')
        end.not_to raise_error
      end

      it 'injects _warnings into the response body' do
        client.send(:check_for_operation_outcomes!, warning_response, '/uhd/v1/allergies?patientId=123')
        expect(warning_response.body['_warnings']).to be_an(Array)
        expect(warning_response.body['_warnings'].size).to eq(1)
        expect(warning_response.body['_warnings'].first).to include(source: 'oracle-health', severity: 'warning')
      end

      it 'logs the warning and increments StatsD' do
        client.send(:check_for_operation_outcomes!, warning_response, '/uhd/v1/allergies?patientId=123')

        expect(Rails.logger).to have_received(:warn).with(
          hash_including(message: 'UHD upstream source returned OperationOutcome warning', resource_type: 'allergies')
        )
        expect(StatsD).to have_received(:increment).with(
          'api.uhd.partial_warning',
          tags: ['source:oracle-health', 'resource_type:allergies']
        )
      end
    end

    context 'when response body is not a Hash (non-FHIR response)' do
      let(:array_response) { Faraday::Response.new(body: [{ 'success' => true }]) }

      it 'does not raise an exception' do
        # Detector only parses when body.is_a?(Hash), so array bodies are skipped entirely
        expect do
          client.send(:check_for_operation_outcomes!, array_response, '/uhd/v1/refill')
        end.not_to raise_error
      end
    end

    context 'when response lacks vista/oracle-health keys' do
      let(:non_scdf_body) do
        {
          'resourceType' => 'OperationOutcome',
          'issue' => [{ 'severity' => 'error', 'code' => 'exception' }]
        }
      end
      let(:response) { Faraday::Response.new(body: non_scdf_body) }

      it 'does not raise an exception' do
        # Detector looks for body['vista'] and body['oracle-health'], finds neither
        expect do
          client.send(:check_for_operation_outcomes!, response, '/some/unknown/path')
        end.not_to raise_error
      end
    end
  end

  # WebMock is used instead of VCR cassettes here because these tests verify URL-encoding
  # of path segments (slashes, spaces, `#`). VCR matches on the final URI so it cannot
  # assert that the client correctly encodes special characters before the request is sent.
  describe '#get_note_by_source' do
    let(:host) { Settings.mhv.uhd.host }
    let(:security_host) { Settings.mhv.uhd.security_host }
    let(:patient_id) { '12345V67890' }
    let(:source) { UnifiedHealthData::SourceConstants::ORACLE_HEALTH }
    let(:record_id) { '20875576613' }
    let(:start_date) { '2024-01-01' }
    let(:end_date) { '2025-06-01' }
    let(:expected_query) { { 'patientId' => patient_id, 'startDate' => start_date, 'endDate' => end_date } }

    before do
      stub_request(:post, "#{security_host}/mhvapi/security/v1/login")
        .to_return(status: 200, headers: { 'authorization' => 'Bearer test-token' })
      stub_request(:get, %r{#{Regexp.escape(host)}/v1/medicalrecords/notes})
        .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
    end

    it 'constructs the correct URL with oracle-health source' do
      client.get_note_by_source(patient_id:, source:, record_id:, start_date:, end_date:)

      expect(WebMock).to have_requested(:get,
                                        "#{host}/v1/medicalrecords/notes/oracle-health/20875576613")
        .with(query: expected_query)
    end

    it 'constructs the correct URL with vista source' do
      vista_source = UnifiedHealthData::SourceConstants::VISTA

      client.get_note_by_source(patient_id:, source: vista_source, record_id:, start_date:, end_date:)

      expect(WebMock).to have_requested(:get,
                                        "#{host}/v1/medicalrecords/notes/vista/20875576613")
        .with(query: expected_query)
    end

    it 'URL-encodes slashes and hashes in record_id' do
      special_record_id = 'F253/7227761#1834074'

      client.get_note_by_source(patient_id:, source:, record_id: special_record_id, start_date:, end_date:)

      expect(WebMock).to have_requested(:get,
                                        "#{host}/v1/medicalrecords/notes/oracle-health/F253%2F7227761%231834074")
        .with(query: expected_query)
    end

    it 'URL-encodes spaces in record_id' do
      spaced_record_id = 'note 123'

      client.get_note_by_source(patient_id:, source:, record_id: spaced_record_id, start_date:, end_date:)

      expect(WebMock).to have_requested(:get,
                                        "#{host}/v1/medicalrecords/notes/oracle-health/note%20123")
        .with(query: expected_query)
    end

    it 'URL-encodes special characters in source' do
      weird_source = 'oracle/health'

      client.get_note_by_source(patient_id:, source: weird_source, record_id:, start_date:, end_date:)

      expect(WebMock).to have_requested(:get,
                                        "#{host}/v1/medicalrecords/notes/oracle%2Fhealth/20875576613")
        .with(query: expected_query)
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
end
