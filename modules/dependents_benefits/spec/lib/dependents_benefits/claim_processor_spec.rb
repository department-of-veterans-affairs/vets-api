# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/claim_processor'

RSpec.describe DependentsBenefits::ClaimProcessor, type: :model do
  before do
    allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
    allow(DependentsBenefits::Monitor).to receive(:new).and_return(mock_monitor)
    allow(mock_monitor).to receive(:track_processor_info)
    allow(mock_monitor).to receive(:track_processor_error)
    allow(mock_monitor).to receive(:track_pension_related_submission)

    allow_any_instance_of(SavedClaim).to receive(:pdf_overflow_tracking)
    allow(processor).to receive(:collect_child_claims).and_return([form_686_claim, form_674_claim])
  end

  let(:parent_claim) { create(:dependents_claim) }
  let(:form_674_claim) { create(:student_claim) }
  let(:form_686_claim) { create(:add_remove_dependents_claim) }
  let(:parent_claim_id) { parent_claim.id }
  let(:proc_id) { 'proc-123-456' }
  let(:processor) { described_class.new(parent_claim_id) }
  let(:mock_monitor) { instance_double(DependentsBenefits::Monitor) }

  describe '.enqueue_submissions' do
    it 'creates processor instance and delegates to instance method' do
      expect(described_class).to receive(:new).with(parent_claim_id).and_return(processor)
      expect(processor).to receive(:enqueue_submissions)
      described_class.enqueue_submissions(parent_claim_id)
    end
  end

  describe '#enqueue_submissions' do
    before do
      allow(DependentsBenefits::Sidekiq::BGS::BGSFormJob).to receive(:perform_async).and_return(true)
      allow(DependentsBenefits::Sidekiq::ClaimsEvidence::ClaimsEvidenceFormJob).to receive(:perform_async).and_return(
        true
      )
      allow(processor).to receive(:collect_child_claims).and_return([form_686_claim, form_674_claim])
    end

    it 'processes claims' do
      expect(DependentsBenefits::Sidekiq::BGS::BGSFormJob).to receive(:perform_async).with(parent_claim_id)
      expect(DependentsBenefits::Sidekiq::ClaimsEvidence::ClaimsEvidenceFormJob).to receive(:perform_async).with(
        parent_claim_id
      )

      result = processor.enqueue_submissions

      expect(result).to eq({ data: { jobs_enqueued: 2 }, error: nil })
    end

    it 'monitors submissions' do
      processor.enqueue_submissions
      expect(mock_monitor).to have_received(:track_processor_info).with(
        'Starting claim submission processing', 'start', { parent_claim_id: }
      )
      expect(mock_monitor).to have_received(:track_processor_info).with(
        'Successfully enqueued all submission jobs', 'enqueue_success', { parent_claim_id:, jobs_count: 2 }
      )
    end

    it 'handles enqueue failures' do
      error = StandardError.new('Enqueue failed')
      allow(mock_monitor).to receive(:track_processor_info).and_raise(error)

      expect(processor).to receive(:handle_enqueue_failure).with(error)
      expect { processor.enqueue_submissions }.to raise_error(StandardError, 'Enqueue failed')
    end
  end

  describe '#collect_child_claims' do
    before do
      allow(processor).to receive(:collect_child_claims).and_call_original
    end

    let!(:parent_group) { create(:parent_claim_group, parent_claim:) }

    it 'tracks and returns child claims' do
      create(:saved_claim_group, saved_claim: form_674_claim, parent_claim:)
      create(:saved_claim_group, saved_claim: form_686_claim, parent_claim:)
      result = processor.send(:collect_child_claims)

      expect(result).to contain_exactly(form_674_claim, form_686_claim)
      expect(mock_monitor).to have_received(:track_processor_info).with(
        'Collected child claims for processing', 'collect_children', { parent_claim_id:, child_claims_count: 2 }
      )
    end

    it 'raises error when no child claims found' do
      # Don't create any child claim groups - only parent group exists
      expect { processor.send(:collect_child_claims) }.to raise_error(
        StandardError, "No child claims found for parent claim #{parent_claim_id}"
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

    it 'logs any errors during failure handling' do
      error = StandardError.new('Original error')
      allow(SavedClaimGroup).to receive(:find_by).and_raise(StandardError.new('DB error'))
      allow(mock_monitor).to receive(:track_processor_error)

      expect(mock_monitor).to receive(:track_processor_error).with(
        'Failed to enqueue submission jobs', 'enqueue_failure', { parent_claim_id:, error: 'Original error' }
      )
      expect(mock_monitor).to receive(:track_processor_error).with(
        'Failed to update ClaimGroup status', 'status_update', { parent_claim_id:, error: 'DB error' }
      )

      processor.send(:handle_enqueue_failure, error)
    end
  end

  describe 'handle_permanent_failure' do
    let!(:parent_group) { create(:parent_claim_group, parent_claim:) }

    it 'logs error' do
      processor.send(:handle_permanent_failure, 'Some error message')
      expect(mock_monitor).to have_received(:track_processor_error).with(
        'Error submitting DependentsBenefits::ClaimProcessor', 'error.permanent', { parent_claim_id:, error: 'Some error message' }
      )
    end

    context 'when parent claim group is not completed' do
      it 'marks parent claim group as failed and sends backup job' do
        parent_group.update(status: SavedClaimGroup::STATUSES[:PROCESSING])
        expect(processor).to receive(:mark_parent_claim_group_failed)
        expect(processor).to receive(:send_backup_job)
        processor.send(:handle_permanent_failure, 'Some error message')
      end
    end

    context 'when parent claim group is already completed' do
      it 'does not mark parent claim group or send backup job' do
        parent_group.update(status: SavedClaimGroup::STATUSES[:SUCCESS])
        expect(processor).not_to receive(:mark_parent_claim_group_failed)
        expect(processor).not_to receive(:send_backup_job)
        processor.send(:handle_permanent_failure, 'Some error message')
      end
    end

    it 'sends error notification email on rescue' do
      allow(processor).to receive(:mark_parent_claim_group_failed).and_raise(StandardError.new('DB error'))
      allow_any_instance_of(DependentsBenefits::NotificationEmail).to receive(:send_error_notification)
      expect_any_instance_of(DependentsBenefits::NotificationEmail).to receive(:send_error_notification)
      expect(mock_monitor).to receive(:log_silent_failure_avoided).with(
        { parent_claim_id:, error: instance_of(StandardError) }
      )
      processor.send(:handle_permanent_failure, 'Some error message')
    end

    it 'logs silent failure if notification email fails' do
      allow(processor).to receive(:mark_parent_claim_group_failed).and_raise(StandardError.new('DB error'))
      allow_any_instance_of(DependentsBenefits::NotificationEmail).to receive(:send_error_notification).and_raise(
        StandardError.new('Email error')
      )
      expect(mock_monitor).to receive(:log_silent_failure).with(
        { parent_claim_id:, error: instance_of(StandardError) }
      )
      processor.send(:handle_permanent_failure, 'Some error message')
    end
  end

  describe '#handle_successful_submission' do
    let!(:parent_group) { create(:parent_claim_group, parent_claim:) }

    it 'logs start of success check' do
      processor.send(:handle_successful_submission)
      expect(mock_monitor).to have_received(:track_processor_info).with(
        'Checking if claim submissions succeeded', 'success_check', { parent_claim_id: }
      )
    end

    it 'handles errors during success handling' do
      allow(processor).to receive(:parent_claim_group).and_raise(StandardError.new('DB error'))
      expect(mock_monitor).to receive(:track_processor_error).with(
        'Error handling successful submission for DependentsBenefits::ClaimProcessor', 'success.error',
        { parent_claim_id:, error: instance_of(StandardError) }
      )
      processor.send(:handle_successful_submission)
    end

    context 'when all child claims succeeded' do
      before do
        allow_any_instance_of(DependentsBenefits::ClaimBehavior).to receive(:submissions_succeeded?).and_return(true)
      end

      context 'and parent claim group not completed' do
        before do
          parent_group.update(status: SavedClaimGroup::STATUSES[:PROCESSING])
        end

        it 'marks parent claim group as succeeded and sends received notification' do
          expect(processor).to receive(:mark_parent_claim_group_succeeded)
          expect_any_instance_of(DependentsBenefits::NotificationEmail).to receive(:send_received_notification)
          processor.send(:handle_successful_submission)
        end

        context 'with pension-related claims' do
          let(:pension_claim) { create(:student_claim) }
          let(:regular_claim) do
            claim = create(:add_remove_dependents_claim)
            claim.parsed_form['dependents_application'].delete('household_income')
            claim
          end

          before do
            allow(Flipper).to receive(:enabled?).with(:va_dependents_net_worth_and_pension).and_return(true)
          end

          it 'tracks pension-related submission when any child claim is pension-related' do
            allow(processor).to receive(:child_claims).and_return([pension_claim, regular_claim])
            expect(mock_monitor).to receive(:track_pension_related_submission).with(
              'Submitted pension-related claim', parent_claim_id:
            )
            processor.send(:handle_successful_submission)
          end

          it 'does not track pension-related submission if no child is pension-related' do
            allow(processor).to receive(:child_claims).and_return([regular_claim])
            expect(mock_monitor).not_to receive(:track_pension_related_submission)
            processor.send(:handle_successful_submission)
          end
        end

        context 'when feature flag is disabled' do
          let(:claim_with_pension_data) { create(:student_claim) }

          before do
            allow(Flipper).to receive(:enabled?).with(:va_dependents_net_worth_and_pension).and_return(false)
            allow(processor).to receive(:child_claims).and_return([claim_with_pension_data])
          end

          it 'does not track pension-related submission when feature flag is disabled' do
            expect(mock_monitor).not_to receive(:track_pension_related_submission)
            processor.send(:handle_successful_submission)
          end
        end
      end

      context 'and parent claim group already completed' do
        before do
          parent_group.update(status: SavedClaimGroup::STATUSES[:SUCCESS])
        end

        it 'does not mark parent claim group or send notification' do
          expect(processor).not_to receive(:mark_parent_claim_group_succeeded)
          expect_any_instance_of(DependentsBenefits::NotificationEmail).not_to receive(:send_received_notification)
          expect(mock_monitor).not_to receive(:track_pension_related_submission)
          processor.send(:handle_successful_submission)
        end
      end
    end

    context 'when not all child claims succeeded' do
      before do
        allow(form_674_claim).to receive(:submissions_succeeded?).and_return(true)
        allow(form_686_claim).to receive(:submissions_succeeded?).and_return(false)
      end

      it 'does not mark parent claim group or send notification' do
        expect(processor).not_to receive(:mark_parent_claim_group_succeeded)
        expect_any_instance_of(DependentsBenefits::NotificationEmail).not_to receive(:send_received_notification)
        expect(mock_monitor).not_to receive(:track_pension_related_submission)
        processor.send(:handle_successful_submission)
      end
    end
  end

  describe '#send_backup_job' do
    it 'enqueues backup submission job' do
      expect(DependentsBenefits::Sidekiq::DependentBackupJob).to receive(:perform_async).with(parent_claim_id)
      processor.send(:send_backup_job)
    end
  end

  describe '#notification_email' do
    it 'returns a DependentsBenefits::NotificationEmail instance' do
      email_instance = processor.send(:notification_email)
      expect(email_instance).to be_a(DependentsBenefits::NotificationEmail)
    end

    it 'memoizes the instance' do
      email_instance1 = processor.send(:notification_email)
      email_instance2 = processor.send(:notification_email)
      expect(email_instance1).to equal(email_instance2)
    end
  end

  describe '#mark_parent_claim_group_succeeded' do
    it 'marks the parent claim group as succeeded' do
      parent_group = create(:parent_claim_group, parent_claim:)
      processor.send(:mark_parent_claim_group_succeeded)
      expect(parent_group.reload.status).to eq(SavedClaimGroup::STATUSES[:SUCCESS])
    end
  end

  describe '#mark_parent_claim_group_failed' do
    it 'marks the parent claim group as failed' do
      parent_group = create(:parent_claim_group, parent_claim:)
      processor.send(:mark_parent_claim_group_failed)
      expect(parent_group.reload.status).to eq(SavedClaimGroup::STATUSES[:FAILURE])
    end
  end
end
