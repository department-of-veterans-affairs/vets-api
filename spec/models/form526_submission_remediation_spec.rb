# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form526SubmissionRemediation, type: :model do
  subject do
    described_class.new(form526_submission:, lifecycle: [])
  end

  let(:form526_submission) { create(:form526_submission) }
  let(:remediate_context) { 'Failed remediation' }

  describe 'associations' do
    it { is_expected.to belong_to(:form526_submission) }
  end

  describe 'validations' do
    context 'remediation_type validation' do
      it 'defines an enum for remediation type' do
        enum_values = %i[manual ignored_as_duplicate email_notified]
        expect(define_enum_for(:remediation_type).with_values(enum_values)).to be_truthy
      end
    end

    context 'lifecycle validation' do
      it 'is invalid without context on create' do
        expect(subject).not_to be_valid
      end

      it 'is invalid without context on update' do
        subject.mark_as_unsuccessful(remediate_context)
        subject.lifecycle << ''
        expect(subject).not_to be_valid
      end
    end

    context 'ignored_as_duplicate validation' do
      before do
        subject.mark_as_unsuccessful(remediate_context)
      end

      it 'is invalid if remediation_type is ignored_as_duplicate and success is false' do
        subject.remediation_type = :ignored_as_duplicate
        subject.success = false
        expect(subject).not_to be_valid
      end

      it 'is valid if ignored_as_duplicate is true and success is true' do
        subject.remediation_type = :ignored_as_duplicate
        subject.success = true
        expect(subject).to be_valid
      end
    end
  end

  describe 'instance methods' do
    describe '#mark_as_unsuccessful' do
      let(:timestamped_context) { "#{Time.current.strftime('%Y-%m-%d %H:%M:%S')} -- #{remediate_context}" }

      it 'transitions the record to success: false' do
        subject.mark_as_unsuccessful(remediate_context)
        expect(subject.success).to be false
      end

      it 'adds timestamped context to lifecycle' do
        subject.mark_as_unsuccessful(remediate_context)
        expect(subject.lifecycle.last).to match(timestamped_context)
      end

      it 'logs the change to Datadog' do
        allow(StatsD).to receive(:increment)

        subject.mark_as_unsuccessful(remediate_context)

        expect(StatsD).to have_received(:increment).with(
          "#{Form526SubmissionRemediation::STATSD_KEY_PREFIX} marked as unsuccessful: #{remediate_context}"
        )
      end

      it 'adds an error if context is not a non-empty string and does not update lifecycle' do
        subject.save
        original_lifecycle = subject.lifecycle.dup
        subject.mark_as_unsuccessful('')

        expect(subject.errors[:base]).to include('Context must be a non-empty string')
        expect(subject.lifecycle).to eq(original_lifecycle)
      end
    end
  end
end
