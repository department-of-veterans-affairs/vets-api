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

    context 'when body is an array (non-SCDF response)' do
      let(:body) { [{ 'success' => true }] }

      it 'returns false without raising' do
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

      it 'does not populate warning_details' do
        expect(detector.warning_details).to be_empty
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

      it 'returns false for partial_failure?' do
        expect(detector.partial_failure?).to be false
      end

      it 'returns true for warnings?' do
        expect(detector.warnings?).to be true
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

  describe '#warnings?' do
    context 'when body is nil' do
      let(:body) { nil }

      it 'returns false' do
        expect(detector.warnings?).to be false
      end
    end

    context 'when no warnings exist' do
      let(:body) do
        {
          'vista' => {
            'entry' => [
              { 'resource' => { 'resourceType' => 'DiagnosticReport', 'id' => '123' } }
            ]
          },
          'oracle-health' => { 'entry' => [] }
        }
      end

      it 'returns false' do
        expect(detector.warnings?).to be false
      end
    end

    context 'when oracle-health has a warning for a missing Binary resource' do
      let(:body) do
        {
          'vista' => {
            'entry' => [
              { 'resource' => { 'resourceType' => 'DiagnosticReport', 'id' => '123' } }
            ]
          },
          'oracle-health' => {
            'entry' => [
              { 'resource' => { 'resourceType' => 'DiagnosticReport', 'id' => '456' } },
              {
                'resource' => {
                  'resourceType' => 'OperationOutcome',
                  'issue' => [
                    {
                      'severity' => 'warning',
                      'code' => 'not-found',
                      'diagnostics' => 'Binary/abc123 for Observation/xyz789 not found'
                    }
                  ]
                }
              }
            ]
          }
        }
      end

      it 'returns true' do
        expect(detector.warnings?).to be true
      end

      it 'does not treat as partial failure' do
        expect(detector.partial_failure?).to be false
      end

      it 'populates warning_details with diagnostic info' do
        expect(detector.warning_details).to contain_exactly(
          hash_including(
            source: 'oracle-health',
            severity: 'warning',
            code: 'not-found',
            diagnostics: 'Binary/abc123 for Observation/xyz789 not found'
          )
        )
      end
    end

    context 'when both errors and warnings exist in the same response' do
      let(:body) do
        {
          'vista' => {
            'entry' => [
              {
                'resource' => {
                  'resourceType' => 'OperationOutcome',
                  'issue' => [
                    { 'severity' => 'error', 'code' => 'timeout', 'diagnostics' => 'Service timed out' }
                  ]
                }
              }
            ]
          },
          'oracle-health' => {
            'entry' => [
              {
                'resource' => {
                  'resourceType' => 'OperationOutcome',
                  'issue' => [
                    { 'severity' => 'warning', 'code' => 'not-found', 'diagnostics' => 'Binary/abc not found' }
                  ]
                }
              }
            ]
          }
        }
      end

      it 'detects both errors and warnings independently' do
        expect(detector.partial_failure?).to be true
        expect(detector.warnings?).to be true
      end

      it 'separates errors into failure_details' do
        expect(detector.failure_details).to contain_exactly(
          hash_including(source: 'vista', severity: 'error')
        )
      end

      it 'separates warnings into warning_details' do
        expect(detector.warning_details).to contain_exactly(
          hash_including(source: 'oracle-health', severity: 'warning')
        )
      end
    end

    context 'when a single OperationOutcome has mixed severity issues' do
      let(:body) do
        {
          'vista' => { 'entry' => [] },
          'oracle-health' => {
            'entry' => [
              {
                'resource' => {
                  'resourceType' => 'OperationOutcome',
                  'issue' => [
                    { 'severity' => 'error', 'code' => 'exception', 'diagnostics' => 'Something failed' },
                    { 'severity' => 'warning', 'code' => 'not-found', 'diagnostics' => 'Binary/123 not found' }
                  ]
                }
              }
            ]
          }
        }
      end

      it 'classifies each issue by its own severity' do
        expect(detector.partial_failure?).to be true
        expect(detector.warnings?).to be true
        expect(detector.failure_details.size).to eq(1)
        expect(detector.warning_details.size).to eq(1)
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

  describe '#log_and_track_warnings' do
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
                    'severity' => 'warning',
                    'code' => 'not-found',
                    'diagnostics' => 'Binary/abc123 for Observation/xyz789 not found'
                  }
                ]
              }
            }
          ]
        }
      }
    end

    it 'logs the warning details' do
      expect(Rails.logger).to receive(:warn).with(
        hash_including(
          message: 'UHD upstream source returned OperationOutcome warning',
          warning_count: 1,
          resource_type: 'labs'
        )
      )

      detector.log_and_track_warnings(user:, resource_type: 'labs')
    end

    it 'increments StatsD warning counter' do
      allow(Rails.logger).to receive(:warn)

      expect(StatsD).to receive(:increment).with(
        'api.uhd.partial_warning',
        tags: ['source:oracle-health', 'resource_type:labs']
      )

      detector.log_and_track_warnings(user:, resource_type: 'labs')
    end

    context 'when no warnings exist' do
      let(:body) do
        {
          'vista' => { 'entry' => [] },
          'oracle-health' => { 'entry' => [] }
        }
      end

      it 'does not log or track' do
        expect(Rails.logger).not_to receive(:warn)
        expect(StatsD).not_to receive(:increment)

        detector.log_and_track_warnings(user:, resource_type: 'labs')
      end
    end
  end
end
