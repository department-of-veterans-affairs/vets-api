# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/models/prescription'

RSpec.describe UnifiedHealthData::Prescription do
  describe '#oracle_health_prescription?' do
    context 'when prescription is from Oracle Health' do
      it 'returns true for VA prescription without refill_submit_date' do
        prescription = described_class.new(
          prescription_source: 'VA',
          refill_submit_date: nil
        )

        expect(prescription.oracle_health_prescription?).to be true
      end
    end

    context 'when prescription is from VistA' do
      it 'returns false when refill_submit_date is present' do
        prescription = described_class.new(
          prescription_source: 'VA',
          refill_submit_date: '2025-06-24T21:05:53.000Z'
        )

        expect(prescription.oracle_health_prescription?).to be false
      end
    end

    context 'when prescription is not from VA' do
      it 'returns false for non-VA prescription source' do
        prescription = described_class.new(
          prescription_source: 'RX',
          refill_submit_date: nil
        )

        expect(prescription.oracle_health_prescription?).to be false
      end
    end
  end

  describe '#refill_metadata_from_tasks' do
    context 'when task_resources are present' do
      it 'extracts refill metadata from most recent Task resource' do
        prescription = described_class.new(
          task_resources: [
            {
              id: '12345',
              status: 'in-progress',
              execution_period_start: '2025-06-24T21:05:53.000Z',
              execution_period_end: nil,
              authored_on: '2025-06-24T20:00:00.000Z',
              last_modified: '2025-06-24T21:00:00.000Z'
            }
          ]
        )

        metadata = prescription.refill_metadata_from_tasks

        expect(metadata[:refill_submit_date]).to eq('2025-06-24T21:05:53.000Z')
        expect(metadata[:refill_request_status]).to eq('in-progress')
        expect(metadata[:task_id]).to eq('12345')
        expect(metadata[:days_since_submission]).to be_a(Integer)
      end

      it 'returns most recent task when multiple tasks exist' do
        prescription = described_class.new(
          task_resources: [
            {
              id: '11111',
              status: 'completed',
              execution_period_start: '2025-06-20T10:00:00.000Z'
            },
            {
              id: '22222',
              status: 'in-progress',
              execution_period_start: '2025-06-24T21:05:53.000Z'
            }
          ]
        )

        metadata = prescription.refill_metadata_from_tasks

        expect(metadata[:task_id]).to eq('22222')
        expect(metadata[:refill_request_status]).to eq('in-progress')
      end

      it 'handles tasks without execution_period_start gracefully' do
        prescription = described_class.new(
          task_resources: [
            {
              id: '12345',
              status: 'requested',
              execution_period_start: nil
            }
          ]
        )

        metadata = prescription.refill_metadata_from_tasks

        expect(metadata[:refill_request_status]).to eq('requested')
        expect(metadata[:task_id]).to eq('12345')
        expect(metadata[:refill_submit_date]).to be_nil
        expect(metadata[:days_since_submission]).to be_nil
      end

      it 'handles invalid date format gracefully' do
        prescription = described_class.new(
          task_resources: [
            {
              id: '12345',
              status: 'in-progress',
              execution_period_start: 'invalid-date'
            }
          ]
        )

        metadata = prescription.refill_metadata_from_tasks

        expect(metadata[:refill_submit_date]).to eq('invalid-date')
        expect(metadata[:days_since_submission]).to be_nil
      end
    end

    context 'when task_resources are empty' do
      it 'returns empty metadata hash' do
        prescription = described_class.new(task_resources: [])

        metadata = prescription.refill_metadata_from_tasks

        expect(metadata).to eq({})
      end
    end

    context 'when task_resources are nil' do
      it 'returns empty metadata hash' do
        prescription = described_class.new(task_resources: nil)

        metadata = prescription.refill_metadata_from_tasks

        expect(metadata).to eq({})
      end
    end

    context 'when tasks have no status' do
      it 'returns empty metadata hash' do
        prescription = described_class.new(
          task_resources: [
            {
              id: '12345',
              status: nil,
              execution_period_start: '2025-06-24T21:05:53.000Z'
            }
          ]
        )

        metadata = prescription.refill_metadata_from_tasks

        expect(metadata).to eq({})
      end
    end
  end
end
