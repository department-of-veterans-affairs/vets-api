# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/claim_processor'

RSpec.describe DependentsBenefits::ClaimProcessor, type: :model do
  let(:parent_claim_id) { 12_345 }
  let(:proc_id) { 'proc-123-456' }
  let(:processor) { described_class.new(parent_claim_id, proc_id) }
  let(:mock_monitor) { instance_double(DependentsBenefits::Monitor) }

  before do
    allow(DependentsBenefits::Monitor).to receive(:new).and_return(mock_monitor)
    allow(mock_monitor).to receive(:track_info_event)
    allow(mock_monitor).to receive(:track_error_event)
  end

  describe '.enqueue_submissions' do
    it 'creates processor instance and delegates to instance method' do
      expect(described_class).to receive(:new).with(parent_claim_id, proc_id).and_return(processor)

      described_class.enqueue_submissions(parent_claim_id, proc_id)
    end
  end

  describe '#enqueue_submissions' do
    let(:form_686c_claim) { create(:dependents_claim, form_id: '21-686C') }
    let(:form_674_claim) { create(:dependents_claim, form_id: '21-674') }
    let(:child_claims) { [form_686c_claim, form_674_claim] }

    before do
      allow(processor).to receive_messages(
        collect_child_claims: child_claims,
        enqueue_686c_submissions: 1,
        enqueue_674_submissions: 1
      )
    end

    it 'processes claims and tracks events' do
      expect(processor).to receive(:enqueue_686c_submissions).with([form_686c_claim])
      expect(processor).to receive(:enqueue_674_submissions).with([form_674_claim])

      result = processor.enqueue_submissions

      expect(result).to eq({ data: { jobs_enqueued: 2 }, error: nil })
      expect(mock_monitor).to have_received(:track_info_event).with(
        'Starting claim submission processing',
        'api.dependents_benefits_processor.start',
        { parent_claim_id:, proc_id: }
      )
      expect(mock_monitor).to have_received(:track_info_event).with(
        'Successfully enqueued all submission jobs',
        'api.dependents_benefits_processor.enqueue_success',
        { parent_claim_id:, jobs_count: 2, proc_id: }
      )
    end

    it 'handles enqueue failures' do
      error = StandardError.new('Enqueue failed')
      allow(processor).to receive(:enqueue_686c_submissions).and_raise(error)
      allow(processor).to receive(:handle_enqueue_failure)

      expect { processor.enqueue_submissions }.to raise_error(StandardError, 'Enqueue failed')
      expect(processor).to have_received(:handle_enqueue_failure).with(error)
    end
  end

  describe '#collect_child_claims' do
    it 'tracks and returns child claims' do
      claim1 = create(:dependents_claim)
      claim2 = create(:dependents_claim)
      allow(SavedClaim).to receive(:where).with(id: []).and_return([claim1, claim2])

      result = processor.send(:collect_child_claims)

      expect(result).to eq([claim1, claim2])
      expect(mock_monitor).to have_received(:track_info_event).with(
        'Collected child claims for processing',
        'api.dependents_benefits_processor.collect_children',
        { parent_claim_id:, child_claims_count: 2, proc_id: }
      )
    end
  end

  describe '#enqueue_686c_submissions and #enqueue_674_submissions' do
    it 'tracks enqueued submissions for both form types' do
      form_686c_claims = [create(:dependents_claim, form_id: '21-686C')]
      form_674_claims = [create(:dependents_claim, form_id: '21-674')]

      processor.send(:enqueue_686c_submissions, form_686c_claims)
      processor.send(:enqueue_674_submissions, form_674_claims)

      expect(mock_monitor).to have_received(:track_info_event).with(
        'Enqueued 686c submission jobs',
        'api.dependents_benefits_processor.enqueue_686c',
        { parent_claim_id:, claim_id: form_686c_claims.first.id, proc_id: }
      )
      expect(mock_monitor).to have_received(:track_info_event).with(
        'Enqueued 674 submission jobs',
        'api.dependents_benefits_processor.enqueue_674',
        { parent_claim_id:, claim_id: form_674_claims.first.id, proc_id: }
      )
    end
  end

  describe '#handle_enqueue_failure' do
    it 'tracks failure' do
      error = StandardError.new('Original error')
      allow(mock_monitor).to receive(:track_error_event)
      expect(mock_monitor).to receive(:track_error_event).with(
        'Failed to enqueue submission jobs',
        'api.dependents_benefits_processor.enqueue_failure',
        instance_of(Hash)
      )

      processor.send(:handle_enqueue_failure, error)
    end
  end
end
