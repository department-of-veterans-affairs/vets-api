# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/sidekiq/bgs/bgs_form_job'
require 'bgsv2/service'

RSpec.describe DependentsBenefits::Sidekiq::BGS::BGSFormJob, type: :job do
  # Create a concrete test class since BGSFormJob is abstract
  let(:test_job_class) do
    Class.new(described_class) do
      def submit_form(_claim_data)
        # No-op for testing
      end

      def form_id
        '21-686C'
      end
    end
  end

  let(:user) { create(:evss_user) }
  let(:parent_claim) { create(:dependents_claim) }
  let(:saved_claim) { create(:add_remove_dependents_claim) }
  let(:user_data) { { 'veteran_information' => { 'full_name' => { 'first' => 'John', 'last' => 'Doe' } } }.to_json }
  let!(:parent_group) { create(:parent_claim_group, parent_claim:, user_data:) }
  let!(:current_group) { create(:saved_claim_group, saved_claim:, parent_claim:) }
  let(:job) { test_job_class.new }

  before do
    # Initialize job with current claim context
    job.instance_variable_set(:@claim_id, saved_claim.id)
  end

  describe '#active_sibling_ep_codes' do
    let(:sibling_claim1) { create(:add_remove_dependents_claim) }
    let(:sibling_claim2) { create(:add_remove_dependents_claim) }
    let(:sibling_claim3) { create(:add_remove_dependents_claim) }

    let!(:sibling_group1) { create(:saved_claim_group, saved_claim: sibling_claim1, parent_claim:) }
    let!(:sibling_group2) { create(:saved_claim_group, saved_claim: sibling_claim2, parent_claim:) }
    let!(:sibling_group3) { create(:saved_claim_group, saved_claim: sibling_claim3, parent_claim:) }

    let(:submission1) { create(:bgs_submission, saved_claim: sibling_claim1, form_id: '21-686C') }
    let(:submission2) { create(:bgs_submission, saved_claim: sibling_claim2, form_id: '21-686C') }
    let(:submission3) { create(:bgs_submission, saved_claim: sibling_claim3, form_id: '21-686C') }

    context 'when no sibling claims have pending submission attempts' do
      it 'returns empty array' do
        # Create only submitted attempts
        create(:bgs_submission_attempt, submission: submission1, status: 'submitted',
                                        metadata: { claim_type_end_product: '130' }.to_json)
        create(:bgs_submission_attempt, submission: submission2, status: 'failure',
                                        metadata: { claim_type_end_product: '131' }.to_json)

        result = job.send(:active_sibling_ep_codes)

        expect(result).to eq([])
      end
    end

    context 'when sibling claims have pending submission attempts with EP codes' do
      it 'returns unique EP codes from pending attempts' do
        create(:bgs_submission_attempt, submission: submission1, status: 'pending',
                                        metadata: { claim_type_end_product: '130' }.to_json)
        create(:bgs_submission_attempt, submission: submission2, status: 'pending',
                                        metadata: { claim_type_end_product: '131' }.to_json)
        create(:bgs_submission_attempt, submission: submission3, status: 'pending',
                                        metadata: { claim_type_end_product: '132' }.to_json)

        result = job.send(:active_sibling_ep_codes)

        expect(result).to contain_exactly('130', '131', '132')
      end
    end

    context 'when multiple pending attempts have the same EP code' do
      it 'returns unique EP codes (no duplicates)' do
        create(:bgs_submission_attempt, submission: submission1, status: 'pending',
                                        metadata: { claim_type_end_product: '130' }.to_json)
        create(:bgs_submission_attempt, submission: submission2, status: 'pending',
                                        metadata: { claim_type_end_product: '130' }.to_json)
        create(:bgs_submission_attempt, submission: submission3, status: 'pending',
                                        metadata: { claim_type_end_product: '131' }.to_json)

        result = job.send(:active_sibling_ep_codes)

        expect(result).to contain_exactly('130', '131')
      end
    end

    context 'when pending attempts have nil or missing claim_type_end_product' do
      it 'excludes nil values and returns only valid EP codes' do
        create(:bgs_submission_attempt, submission: submission1, status: 'pending',
                                        metadata: { claim_type_end_product: '130' }.to_json)
        create(:bgs_submission_attempt, submission: submission2, status: 'pending',
                                        metadata: { other_field: 'value' }.to_json)
        create(:bgs_submission_attempt, submission: submission3, status: 'pending', metadata: nil)

        result = job.send(:active_sibling_ep_codes)

        expect(result).to contain_exactly('130')
      end
    end

    context 'when mixing pending and non-pending attempts' do
      it 'returns only EP codes from pending attempts' do
        create(:bgs_submission_attempt, submission: submission1, status: 'pending',
                                        metadata: { claim_type_end_product: '130' }.to_json)
        create(:bgs_submission_attempt, submission: submission2, status: 'submitted',
                                        metadata: { claim_type_end_product: '131' }.to_json)
        create(:bgs_submission_attempt, submission: submission3, status: 'failure',
                                        metadata: { claim_type_end_product: '132' }.to_json)

        result = job.send(:active_sibling_ep_codes)

        expect(result).to eq(['130'])
      end
    end

    context 'when parent claim has no child claims' do
      let(:orphan_claim) { create(:dependents_claim) }
      let(:orphan_saved_claim) { create(:add_remove_dependents_claim) }
      let!(:orphan_parent_group) { create(:parent_claim_group, parent_claim: orphan_claim, user_data:) }
      let!(:orphan_current_group) do
        create(:saved_claim_group, saved_claim: orphan_saved_claim, parent_claim: orphan_claim)
      end

      before do
        job.instance_variable_set(:@claim_id, orphan_saved_claim.id)
      end

      it 'returns empty array' do
        result = job.send(:active_sibling_ep_codes)

        expect(result).to eq([])
      end
    end
  end

  describe '#claim_type_end_product' do
    let(:bgs_service) { instance_double(BGSV2::Service) }

    before do
      allow(BGSV2::Service).to receive(:new).and_return(bgs_service)
    end

    context 'when claim_type_end_product is already set' do
      it 'returns memoized value' do
        job.instance_variable_set(:@claim_type_end_product, '130')

        expect(bgs_service).not_to receive(:find_active_benefit_claim_type_increments)
        expect(job.send(:claim_type_end_product)).to eq('130')
      end
    end

    context 'when selecting from available EP codes' do
      let(:sibling_claim) { create(:add_remove_dependents_claim) }
      let!(:sibling_group) { create(:saved_claim_group, saved_claim: sibling_claim, parent_claim:) }
      let(:sibling_submission) { create(:bgs_submission, saved_claim: sibling_claim, form_id: '21-686C') }

      before do
        # Mock active claim EP codes from BGS
        allow(bgs_service).to receive(:find_active_benefit_claim_type_increments).and_return(%w[131 134])
      end

      it 'excludes active claim EP codes and active sibling EP codes' do
        # Sibling has pending attempt with '130'
        create(:bgs_submission_attempt, submission: sibling_submission, status: 'pending',
                                        metadata: { claim_type_end_product: '130' }.to_json)

        result = job.send(:claim_type_end_product)

        # Should exclude: 130 (sibling), 131 (active), 134 (active)
        # Available: 132, 136, 137, 138, 139
        expect(result).to eq('132')
      end

      it 'returns first available EP code when all are available' do
        allow(bgs_service).to receive(:find_active_benefit_claim_type_increments).and_return([])

        result = job.send(:claim_type_end_product)

        expect(result).to eq('130')
      end

      it 'returns nil when no EP codes are available' do
        # All codes are active
        allow(bgs_service).to receive(:find_active_benefit_claim_type_increments)
          .and_return(%w[130 131 132 134 136 137 138 139])

        result = job.send(:claim_type_end_product)

        expect(result).to be_nil
      end
    end
  end

  describe '#record_ep_code_in_submission_attempt' do
    let(:submission) { create(:bgs_submission, saved_claim:, form_id: '21-686C') }
    let(:submission_attempt) { create(:bgs_submission_attempt, submission:, metadata: nil) }

    before do
      job.instance_variable_set(:@submission_attempt, submission_attempt)
      job.instance_variable_set(:@claim_type_end_product, '130')
    end

    context 'when metadata is nil' do
      it 'creates metadata with claim_type_end_product' do
        job.send(:record_ep_code_in_submission_attempt)
        submission_attempt.reload

        metadata = JSON.parse(submission_attempt.metadata, symbolize_names: true)
        expect(metadata[:claim_type_end_product]).to eq('130')
      end
    end

    context 'when metadata already exists' do
      before do
        submission_attempt.update(metadata: { other_field: 'value' }.to_json)
      end

      it 'adds claim_type_end_product to existing metadata' do
        job.send(:record_ep_code_in_submission_attempt)
        submission_attempt.reload
        metadata = JSON.parse(submission_attempt.metadata, symbolize_names: true)
        expect(metadata[:claim_type_end_product]).to eq('130')
        expect(metadata[:other_field]).to eq('value')
      end
    end

    it 'persists the metadata to the database' do
      expect { job.send(:record_ep_code_in_submission_attempt) }
        .to(change { submission_attempt.reload.metadata })
    end
  end

  describe '#find_or_create_form_submission' do
    it 'creates a new BGS::Submission if one does not exist' do
      expect do
        job.send(:find_or_create_form_submission)
      end.to change(BGS::Submission, :count).by(1)
    end

    it 'returns existing BGS::Submission if one already exists' do
      existing_submission = create(:bgs_submission, saved_claim:, form_id: '21-686C')

      result = job.send(:find_or_create_form_submission)

      expect(result).to eq(existing_submission)
      expect(BGS::Submission.count).to eq(1)
    end

    it 'memoizes the submission' do
      first_call = job.send(:find_or_create_form_submission)
      second_call = job.send(:find_or_create_form_submission)

      expect(first_call).to be(second_call)
    end
  end

  describe '#create_form_submission_attempt' do
    let(:submission) { create(:bgs_submission, saved_claim:, form_id: '21-686C') }

    before do
      job.instance_variable_set(:@submission, submission)
    end

    it 'creates a new BGS::SubmissionAttempt' do
      expect do
        job.send(:create_form_submission_attempt)
      end.to change(BGS::SubmissionAttempt, :count).by(1)
    end

    it 'associates the attempt with the submission' do
      attempt = job.send(:create_form_submission_attempt)

      expect(attempt.submission).to eq(submission)
    end

    it 'memoizes the submission attempt' do
      first_call = job.send(:create_form_submission_attempt)
      second_call = job.send(:create_form_submission_attempt)

      expect(first_call).to be(second_call)
    end
  end

  describe '#mark_submission_succeeded' do
    let(:submission) { create(:bgs_submission, saved_claim:, form_id: '21-686C') }
    let(:submission_attempt) { create(:bgs_submission_attempt, submission:, status: 'pending') }

    before do
      job.instance_variable_set(:@submission_attempt, submission_attempt)
    end

    it 'marks the submission attempt as submitted' do
      expect { job.send(:mark_submission_succeeded) }
        .to change { submission_attempt.reload.status }.from('pending').to('submitted')
    end

    it 'handles nil submission_attempt gracefully' do
      job.instance_variable_set(:@submission_attempt, nil)

      expect { job.send(:mark_submission_succeeded) }.not_to raise_error
    end
  end

  describe '#mark_submission_attempt_failed' do
    let(:submission) { create(:bgs_submission, saved_claim:, form_id: '21-686C') }
    let(:submission_attempt) { create(:bgs_submission_attempt, submission:, status: 'pending') }
    let(:error) { StandardError.new('Test error') }

    before do
      job.instance_variable_set(:@submission_attempt, submission_attempt)
    end

    it 'marks the submission attempt as failure' do
      expect { job.send(:mark_submission_attempt_failed, error) }
        .to change { submission_attempt.reload.status }.from('pending').to('failure')
    end

    it 'records the error message' do
      job.send(:mark_submission_attempt_failed, error)
      submission_attempt.reload

      expect(submission_attempt.error_message).to eq('Test error')
    end

    it 'handles nil submission_attempt gracefully' do
      job.instance_variable_set(:@submission_attempt, nil)

      expect { job.send(:mark_submission_attempt_failed, error) }.not_to raise_error
    end
  end

  describe '#permanent_failure?' do
    before do
      stub_const('BGS::Job::FILTERED_ERRORS', %w[INVALID_SSN DUPLICATE_CLAIM])
    end

    context 'when error is nil' do
      it 'returns false' do
        expect(job.send(:permanent_failure?, nil)).to be false
      end
    end

    context 'when error message contains filtered error' do
      it 'returns true for INVALID_SSN' do
        error = StandardError.new('INVALID_SSN: Social Security Number is invalid')

        expect(job.send(:permanent_failure?, error)).to be true
      end

      it 'returns true for DUPLICATE_CLAIM' do
        error = StandardError.new('DUPLICATE_CLAIM: This claim already exists')

        expect(job.send(:permanent_failure?, error)).to be true
      end
    end

    context 'when error cause contains filtered error' do
      it 'returns true when cause message matches' do
        cause = StandardError.new('INVALID_SSN: Social Security Number is invalid')
        error = StandardError.new('Wrapped error')
        allow(error).to receive(:cause).and_return(cause)

        expect(job.send(:permanent_failure?, error)).to be true
      end
    end

    context 'when error does not contain filtered error' do
      it 'returns false' do
        error = StandardError.new('Temporary network error')

        expect(job.send(:permanent_failure?, error)).to be false
      end
    end
  end
end
