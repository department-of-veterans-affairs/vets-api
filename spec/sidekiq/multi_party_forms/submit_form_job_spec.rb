# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultiPartyForms::SubmitFormJob, type: :job do
  subject(:job) { described_class.new }

  let(:primary_form_data) { { 'veteran_name' => 'John Doe' }.to_json }
  let(:secondary_form_data) { { 'physician_name' => 'Dr. Smith' }.to_json }
  let(:merged_data) { { 'veteran_name' => 'John Doe', 'physician_name' => 'Dr. Smith' } }

  let(:primary_in_progress_form) do
    create(:in_progress_form, form_id: '21-2680-PRIMARY', form_data: primary_form_data)
  end
  let(:secondary_in_progress_form) do
    create(:in_progress_form, form_id: '21-2680-SECONDARY', form_data: secondary_form_data)
  end
  let(:submission) do
    create(
      :multi_party_form_submission,
      form_type: '21-2680-PRIMARY',
      status: 'secondary_in_progress',
      primary_in_progress_form:,
      secondary_in_progress_form:
    )
  end
  let(:saved_claim) { create(:fake_saved_claim) }
  let(:merge_service_instance) { double(merge: merged_data) }
  let(:merge_service_class) { double(new: merge_service_instance) }

  before do
    stub_const('MultiPartyForms::Form212680PRIMARY::MergeService', merge_service_class)
    allow(SavedClaim).to receive(:create!).and_return(saved_claim)
    allow(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform_async)
    allow(StatsD).to receive(:increment)
  end

  describe '#perform' do
    context 'when the submission is successful' do
      it 'retrieves form data from both InProgressForms and calls the MergeService' do
        expect(merge_service_class).to receive(:new)
          .with(primary_form_data, secondary_form_data)
          .and_return(merge_service_instance)

        job.perform(submission.id)
      end

      it 'creates a SavedClaim with the merged data' do
        expect(SavedClaim).to receive(:create!).with(
          form_id: '21-2680-PRIMARY',
          form_data: merged_data.to_json
        ).and_return(saved_claim)

        job.perform(submission.id)
      end

      it 'associates the SavedClaim with the submission' do
        job.perform(submission.id)

        expect(submission.reload.saved_claim).to eq(saved_claim)
      end

      it 'enqueues the Lighthouse submission job' do
        expect(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform_async).with(saved_claim.id)

        job.perform(submission.id)
      end

      it 'destroys both InProgressForms' do
        job.perform(submission.id)

        expect(InProgressForm.exists?(primary_in_progress_form.id)).to be(false)
        expect(InProgressForm.exists?(secondary_in_progress_form.id)).to be(false)
      end

      it 'tracks StatsD begin and success metrics' do
        job.perform(submission.id)

        expect(StatsD).to have_received(:increment).with("#{described_class::STATSD_KEY_PREFIX}.begin")
        expect(StatsD).to have_received(:increment).with("#{described_class::STATSD_KEY_PREFIX}.success")
      end
    end

    context 'when the MergeService raises an error' do
      before do
        allow(merge_service_instance).to receive(:merge).and_raise(StandardError, 'merge failed')
      end

      it 'increments the failure StatsD metric and re-raises' do
        expect { job.perform(submission.id) }.to raise_error(StandardError, 'merge failed')

        expect(StatsD).to have_received(:increment).with("#{described_class::STATSD_KEY_PREFIX}.begin")
        expect(StatsD).to have_received(:increment).with("#{described_class::STATSD_KEY_PREFIX}.failure")
      end

      it 'does not create a SavedClaim' do
        expect(SavedClaim).not_to receive(:create!)

        expect { job.perform(submission.id) }.to raise_error(StandardError)
      end

      it 'does not enqueue the Lighthouse submission job' do
        expect(Lighthouse::SubmitBenefitsIntakeClaim).not_to receive(:perform_async)

        expect { job.perform(submission.id) }.to raise_error(StandardError)
      end
    end

    context 'when SavedClaim creation fails' do
      before do
        allow(SavedClaim).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'increments the failure StatsD metric and re-raises' do
        expect { job.perform(submission.id) }.to raise_error(ActiveRecord::RecordInvalid)

        expect(StatsD).to have_received(:increment).with("#{described_class::STATSD_KEY_PREFIX}.begin")
        expect(StatsD).to have_received(:increment).with("#{described_class::STATSD_KEY_PREFIX}.failure")
      end

      it 'does not associate a SavedClaim with the submission' do
        expect { job.perform(submission.id) }.to raise_error(ActiveRecord::RecordInvalid)

        expect(submission.reload.saved_claim).to be_nil
      end

      it 'does not enqueue the Lighthouse submission job' do
        expect(Lighthouse::SubmitBenefitsIntakeClaim).not_to receive(:perform_async)

        expect { job.perform(submission.id) }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when no MergeService exists for the form type' do
      before do
        hide_const('MultiPartyForms::Form212680PRIMARY::MergeService')
      end

      it 'raises NotImplementedError and increments failure metric' do
        expect { job.perform(submission.id) }
          .to raise_error(described_class::MergeServiceNotFoundError, /No MergeService found/)

        expect(StatsD).to have_received(:increment).with("#{described_class::STATSD_KEY_PREFIX}.failure")
      end
    end
  end
end
