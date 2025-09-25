# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/claim_processor'

RSpec.describe DependentsBenefits::ClaimProcessor, type: :model do
  let(:parent_claim) { create(:dependents_claim) }
  let(:form_674_claim) { create(:student_claim) }
  let(:form_686_claim) { create(:add_remove_dependents_claim) }
  let(:parent_claim_id) { parent_claim.id }
  let(:proc_id) { 'proc-123-456' }
  let(:processor) { described_class.new(parent_claim_id, proc_id) }
  let(:mock_monitor) { instance_double(DependentsBenefits::Monitor) }

  before do
    allow(DependentsBenefits::Monitor).to receive(:new).and_return(mock_monitor)
    allow(mock_monitor).to receive(:track_processor_info)
    allow(mock_monitor).to receive(:track_processor_error)

    allow_any_instance_of(SavedClaim).to receive(:pdf_overflow_tracking)
  end

  describe '.enqueue_submissions' do
    it 'creates processor instance and delegates to instance method' do
      expect(described_class).to receive(:new).with(parent_claim_id, proc_id).and_return(processor)
      expect(processor).to receive(:enqueue_submissions)
      described_class.enqueue_submissions(parent_claim_id, proc_id)
    end
  end

  describe '#enqueue_submissions' do
    it 'processes claims and tracks events' do
      allow(processor).to receive(:collect_child_claims).and_return([form_686_claim, form_674_claim])

      expect(processor).to receive(:enqueue_686c_submission).with(form_686_claim).and_return(1)
      expect(processor).to receive(:enqueue_674_submission).with(form_674_claim).and_return(1)

      result = processor.enqueue_submissions

      expect(result).to eq({ data: { jobs_enqueued: 2 }, error: nil })
      expect(mock_monitor).to have_received(:track_processor_info).with(
        'Starting claim submission processing', 'start', { parent_claim_id: }
      )
      expect(mock_monitor).to have_received(:track_processor_info).with(
        'Successfully enqueued all submission jobs', 'enqueue_success', { parent_claim_id:, jobs_count: 2 }
      )
    end

    it 'handles enqueue failures' do
      error = StandardError.new('Enqueue failed')
      allow(processor).to receive(:enqueue_686c_submission).and_raise(error)
      allow(processor).to receive(:handle_enqueue_failure)
      allow(processor).to receive(:collect_child_claims).and_return([form_686_claim, form_674_claim])

      expect(processor).not_to receive(:enqueue_674_submission)

      expect { processor.enqueue_submissions }.to raise_error(StandardError, 'Enqueue failed')
      expect(processor).to have_received(:handle_enqueue_failure).with(error)
    end
  end

  describe '#collect_child_claims' do
    let!(:parent_group) { create(:parent_claim_group, parent_claim:) }
    let!(:form_674_group) { create(:saved_claim_group, saved_claim: form_674_claim, parent_claim:) }
    let!(:form_686_group) { create(:saved_claim_group, saved_claim: form_686_claim, parent_claim:) }

    it 'tracks and returns child claims' do
      result = processor.send(:collect_child_claims)

      expect(result).to contain_exactly(form_674_claim, form_686_claim)
      expect(mock_monitor).to have_received(:track_processor_info).with(
        'Collected child claims for processing', 'collect_children', { parent_claim_id:, child_claims_count: 2 }
      )
    end
  end

  describe '#enqueue_686c_submissions and #enqueue_674_submissions' do
    it 'tracks enqueued submissions for both form types' do
      processor.send(:enqueue_686c_submission, form_686_claim)
      processor.send(:enqueue_674_submission, form_674_claim)

      expect(mock_monitor).to have_received(:track_processor_info).with(
        'Enqueued 686c submission jobs', 'enqueue_686c', { parent_claim_id:, claim_id: form_686_claim.id }
      )
      expect(mock_monitor).to have_received(:track_processor_info).with(
        'Enqueued 674 submission jobs', 'enqueue_674', { parent_claim_id:, claim_id: form_674_claim.id }
      )
    end
  end

  describe '#handle_enqueue_failure' do
    let(:claim_group) { create(:saved_claim_group, saved_claim: form_686_claim, parent_claim:) }

    it 'tracks failure' do
      error = StandardError.new('Original error')
      allow(SavedClaimGroup).to receive(:find_by).and_return(claim_group)
      allow(mock_monitor).to receive(:track_processor_error)

      expect(mock_monitor).to receive(:track_processor_error).with(
        'Failed to enqueue submission jobs', 'enqueue_failure', instance_of(Hash)
      )

      processor.send(:handle_enqueue_failure, error)
      expect(claim_group.status).to eq('failure')
    end
  end
end
