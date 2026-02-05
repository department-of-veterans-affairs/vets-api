# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/operation_outcome_detector'

RSpec.describe UnifiedHealthData::OperationOutcomeDetector do
  subject(:detector) { described_class.new(body) }

  describe '#partial_failure?' do
    context 'when body is nil' do
      let(:body) { nil }

      it 'returns false' do
        expect(detector.partial_failure?).to be false
      end
    end

    context 'when body has no OperationOutcome entries' do
      let(:body) do
        {
          'vista' => {
            'entry' => [
              { 'resource' => { 'resourceType' => 'MedicationRequest', 'id' => '123' } }
            ]
          },
          'oracle-health' => {
            'entry' => [
              { 'resource' => { 'resourceType' => 'MedicationRequest', 'id' => '456' } }
            ]
          }
        }
      end

      it 'returns false' do
        expect(detector.partial_failure?).to be false
      end
    end

    context 'when vista source has OperationOutcome with error severity' do
      let(:body) do
        {
          'vista' => {
            'entry' => [
              { 'resource' => { 'resourceType' => 'MedicationRequest', 'id' => '123' } }
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
                      'diagnostics' => 'Exhausted retry attempts...giving up'
                    }
                  ]
                }
              }
            ]
          }
        }
      end

      it 'returns true' do
        expect(detector.partial_failure?).to be true
      end

      it 'populates failed_sources with oracle-health' do
        detector.partial_failure?
        expect(detector.failed_sources).to eq(['oracle-health'])
      end

      it 'populates failure_details with diagnostic info' do
        detector.partial_failure?
        expect(detector.failure_details).to include(
          hash_including(
            source: 'oracle-health',
            severity: 'error',
            code: 'exception',
            diagnostics: 'Exhausted retry attempts...giving up'
          )
        )
      end
    end

    context 'when oracle-health source has OperationOutcome with error severity' do
      let(:body) do
        {
          'vista' => {
            'entry' => [
              {
                'resource' => {
                  'resourceType' => 'OperationOutcome',
                  'issue' => [
                    {
                      'severity' => 'error',
                      'code' => 'timeout',
                      'diagnostics' => 'Service timed out'
                    }
                  ]
                }
              }
            ]
          },
          'oracle-health' => {
            'entry' => [
              { 'resource' => { 'resourceType' => 'MedicationRequest', 'id' => '456' } }
            ]
          }
        }
      end

      it 'returns true' do
        expect(detector.partial_failure?).to be true
      end

      it 'populates failed_sources with vista' do
        detector.partial_failure?
        expect(detector.failed_sources).to eq(['vista'])
      end
    end

    context 'when both sources have OperationOutcome errors' do
      let(:body) do
        {
          'vista' => {
            'entry' => [
              {
                'resource' => {
                  'resourceType' => 'OperationOutcome',
                  'issue' => [{ 'severity' => 'error', 'code' => 'timeout' }]
                }
              }
            ]
          },
          'oracle-health' => {
            'entry' => [
              {
                'resource' => {
                  'resourceType' => 'OperationOutcome',
                  'issue' => [{ 'severity' => 'error', 'code' => 'exception' }]
                }
              }
            ]
          }
        }
      end

      it 'returns true' do
        expect(detector.partial_failure?).to be true
      end

      it 'populates failed_sources with both sources' do
        detector.partial_failure?
        expect(detector.failed_sources).to contain_exactly('vista', 'oracle-health')
      end
    end

    context 'when OperationOutcome has warning severity (not error)' do
      let(:body) do
        {
          'vista' => {
            'entry' => [
              {
                'resource' => {
                  'resourceType' => 'OperationOutcome',
                  'issue' => [{ 'severity' => 'warning', 'code' => 'informational' }]
                }
              }
            ]
          },
          'oracle-health' => { 'entry' => [] }
        }
      end

      it 'returns false' do
        expect(detector.partial_failure?).to be false
      end
    end

    context 'when OperationOutcome has fatal severity' do
      let(:body) do
        {
          'vista' => { 'entry' => [] },
          'oracle-health' => {
            'entry' => [
              {
                'resource' => {
                  'resourceType' => 'OperationOutcome',
                  'issue' => [{ 'severity' => 'fatal', 'code' => 'exception' }]
                }
              }
            ]
          }
        }
      end

      it 'returns true' do
        expect(detector.partial_failure?).to be true
      end
    end

    context 'when entry is nil for a source' do
      let(:body) do
        {
          'vista' => { 'entry' => nil },
          'oracle-health' => nil
        }
      end

      it 'returns false without raising' do
        expect(detector.partial_failure?).to be false
      end
    end
  end

  describe '#log_and_track' do
    let(:user) { build(:user, :loa3) }
    let(:body) do
      {
        'vista' => { 'entry' => [] },
        'oracle-health' => {
          'entry' => [
            {
              'resource' => {
                'resourceType' => 'OperationOutcome',
                'issue' => [
                  {
                    'severity' => 'error',
                    'code' => 'exception',
                    'diagnostics' => 'Rate limit exceeded'
                  }
                ]
              }
            }
          ]
        }
      }
    end

    before do
      detector.partial_failure?
    end

    it 'logs the partial failure' do
      expect(Rails.logger).to receive(:warn).with(
        hash_including(
          message: 'UHD upstream source returned OperationOutcome error',
          failed_sources: ['oracle-health'],
          resource_type: 'medications'
        )
      )

      detector.log_and_track(user:, resource_type: 'medications')
    end

    it 'increments StatsD counter' do
      allow(Rails.logger).to receive(:warn)

      expect(StatsD).to receive(:increment).with(
        'api.uhd.partial_failure',
        tags: ['source:oracle-health', 'resource_type:medications']
      )

      detector.log_and_track(user:, resource_type: 'medications')
    end

    context 'when both sources failed' do
      let(:body) do
        {
          'vista' => {
            'entry' => [
              {
                'resource' => {
                  'resourceType' => 'OperationOutcome',
                  'issue' => [{ 'severity' => 'error', 'code' => 'timeout' }]
                }
              }
            ]
          },
          'oracle-health' => {
            'entry' => [
              {
                'resource' => {
                  'resourceType' => 'OperationOutcome',
                  'issue' => [{ 'severity' => 'error', 'code' => 'exception' }]
                }
              }
            ]
          }
        }
      end

      it 'increments StatsD for each failed source' do
        allow(Rails.logger).to receive(:warn)

        expect(StatsD).to receive(:increment).with(
          'api.uhd.partial_failure',
          tags: ['source:vista', 'resource_type:allergies']
        )
        expect(StatsD).to receive(:increment).with(
          'api.uhd.partial_failure',
          tags: ['source:oracle-health', 'resource_type:allergies']
        )

        detector.log_and_track(user:, resource_type: 'allergies')
      end
    end
  end
end
