# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormIntakeSubmission, type: :model do
  let(:form_submission) { create(:form_submission) }
  let(:form_intake_submission) do
    create(:form_intake_submission,
           form_submission:,
           benefits_intake_uuid: SecureRandom.uuid)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:form_submission) }
  end

  describe 'validations' do
    describe 'retry_count' do
      it 'validates numericality' do
        expect(form_intake_submission).to validate_numericality_of(:retry_count)
          .is_greater_than_or_equal_to(0)
      end

      it 'allows zero' do
        form_intake_submission.retry_count = 0
        expect(form_intake_submission).to be_valid
      end

      it 'allows positive numbers' do
        form_intake_submission.retry_count = 5
        expect(form_intake_submission).to be_valid
      end

      it 'does not allow negative numbers' do
        form_intake_submission.retry_count = -1
        expect(form_intake_submission).not_to be_valid
      end
    end

    describe 'benefits_intake_uuid' do
      it 'requires presence' do
        form_intake_submission.benefits_intake_uuid = nil
        expect(form_intake_submission).not_to be_valid
        expect(form_intake_submission.errors[:benefits_intake_uuid]).to include("can't be blank")
      end
    end

    describe 'form_submission' do
      it 'requires presence' do
        submission = build(:form_intake_submission, form_submission: nil)
        expect(submission).not_to be_valid
        expect(submission.errors[:form_submission]).to include('must exist')
      end
    end
  end

  describe 'scopes' do
    let!(:pending_submission) { create(:form_intake_submission, aasm_state: 'pending') }
    let!(:submitted_submission) { create(:form_intake_submission, aasm_state: 'submitted') }
    let!(:success_submission) { create(:form_intake_submission, aasm_state: 'success') }
    let!(:failed_submission) { create(:form_intake_submission, aasm_state: 'failed') }
    let!(:old_submission) { create(:form_intake_submission, aasm_state: 'pending', created_at: 10.days.ago) }
    let!(:stale_pending_submission) do
      create(:form_intake_submission, aasm_state: 'pending', created_at: 2.days.ago)
    end

    describe '.pending' do
      it 'returns only pending submissions' do
        expect(described_class.pending).to include(pending_submission, stale_pending_submission)
        expect(described_class.pending).not_to include(submitted_submission, success_submission, failed_submission)
      end
    end

    describe '.submitted' do
      it 'returns only submitted submissions' do
        expect(described_class.submitted).to eq([submitted_submission])
      end
    end

    describe '.success' do
      it 'returns only successful submissions' do
        expect(described_class.success).to eq([success_submission])
      end
    end

    describe '.failed' do
      it 'returns only failed submissions' do
        expect(described_class.failed).to eq([failed_submission])
      end
    end

    describe '.recent' do
      it 'returns submissions from the last 7 days' do
        expect(described_class.recent).to include(
          pending_submission,
          submitted_submission,
          success_submission,
          failed_submission,
          stale_pending_submission
        )
        expect(described_class.recent).not_to include(old_submission)
      end
    end

    describe '.stale_pending' do
      it 'returns pending submissions older than 1 day' do
        expect(described_class.stale_pending).to contain_exactly(old_submission, stale_pending_submission)
        expect(described_class.stale_pending).not_to include(pending_submission)
      end
    end
  end

  describe 'state machine' do
    describe 'initial state' do
      it 'starts in pending state' do
        submission = described_class.new(
          form_submission:,
          benefits_intake_uuid: SecureRandom.uuid
        )
        expect(submission.aasm_state).to eq('pending')
      end
    end

    describe 'submit event' do
      it 'transitions from pending to submitted' do
        submission = create(:form_intake_submission, aasm_state: 'pending')
        expect(submission)
          .to transition_from(:pending).to(:submitted).on_event(:submit)
      end

      it 'sets submitted_at timestamp' do
        submission = create(:form_intake_submission, aasm_state: 'pending')
        Timecop.freeze(Time.current) do
          submission.submit!
          expect(submission.submitted_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'logs the status change' do
        submission = create(:form_intake_submission, aasm_state: 'pending')
        expect(Rails.logger).to receive(:info).with(hash_including(
                                                      message: 'Form Intake Submission submitted to GCIO',
                                                      form_intake_submission_id: submission.id
                                                    ))
        submission.submit!
      end
    end

    context 'transitioning to a success state' do
      it 'transitions from submitted to success' do
        submission = create(:form_intake_submission, aasm_state: 'submitted')
        expect(submission)
          .to transition_from(:submitted).to(:success).on_event(:succeed)
      end

      it 'sets completed_at timestamp' do
        submission = create(:form_intake_submission, aasm_state: 'submitted')
        Timecop.freeze(Time.current) do
          submission.succeed!
          expect(submission.completed_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'logs success metrics to StatsD' do
        submission = create(:form_intake_submission, aasm_state: 'submitted')
        expect(StatsD).to receive(:increment).with(
          'form_intake.submission.success',
          tags: [
            "form_type:#{submission.form_type}",
            "retry_count:#{submission.retry_count}"
          ]
        )
        submission.succeed!
      end

      it 'logs the status change' do
        submission = create(:form_intake_submission, aasm_state: 'submitted')
        expect(Rails.logger).to receive(:info).with(hash_including(
                                                      message: 'Form Intake Submission succeeded',
                                                      form_intake_submission_id: submission.id
                                                    ))
        submission.succeed!
      end
    end

    context 'transitioning to a failure state' do
      it 'transitions from pending to failed' do
        submission = create(:form_intake_submission, aasm_state: 'pending')
        expect(submission)
          .to transition_from(:pending).to(:failed).on_event(:fail)
      end

      it 'transitions from submitted to failed' do
        submission = create(:form_intake_submission, aasm_state: 'submitted')
        expect(submission)
          .to transition_from(:submitted).to(:failed).on_event(:fail)
      end

      it 'sets completed_at timestamp' do
        submission = create(:form_intake_submission, aasm_state: 'submitted')
        Timecop.freeze(Time.current) do
          submission.fail!
          expect(submission.completed_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'logs failure metrics to StatsD' do
        submission = create(:form_intake_submission, aasm_state: 'submitted')
        expect(StatsD).to receive(:increment).with(
          'form_intake.submission.failed',
          tags: [
            "form_type:#{submission.form_type}",
            "retry_count:#{submission.retry_count}"
          ]
        )
        submission.fail!
      end

      it 'logs the status change as error' do
        submission = create(:form_intake_submission, aasm_state: 'submitted')
        expect(Rails.logger).to receive(:error).with(hash_including(
                                                       message: 'Form Intake Submission failed',
                                                       form_intake_submission_id: submission.id
                                                     ))
        submission.fail!
      end
    end

    describe 'invalid transitions' do
      it 'does not allow transitioning from success to failed' do
        submission = create(:form_intake_submission, aasm_state: 'success')
        expect { submission.fail! }.to raise_error(AASM::InvalidTransition)
      end

      it 'does not allow transitioning from failed to success' do
        submission = create(:form_intake_submission, aasm_state: 'failed')
        expect { submission.succeed! }.to raise_error(AASM::InvalidTransition)
      end
    end
  end

  describe '#increment_retry_count!' do
    it 'increments the retry_count by 1' do
      submission = create(:form_intake_submission, retry_count: 0)
      expect { submission.increment_retry_count! }.to change(submission, :retry_count).from(0).to(1)
    end

    it 'updates last_attempted_at timestamp' do
      submission = create(:form_intake_submission, last_attempted_at: 1.hour.ago)
      Timecop.freeze(Time.current) do
        submission.increment_retry_count!
        expect(submission.last_attempted_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'persists changes to database' do
      submission = create(:form_intake_submission, retry_count: 0)
      submission.increment_retry_count!
      submission.reload
      expect(submission.retry_count).to eq(1)
    end
  end

  describe '#form_type' do
    it 'returns form_type from associated form_submission' do
      form_submission = create(:form_submission, form_type: '21P-601')
      submission = create(:form_intake_submission, form_submission:)
      expect(submission.form_type).to eq('21P-601')
    end

    it 'returns nil when form_submission is not present' do
      submission = build(:form_intake_submission, form_submission: nil)
      expect(submission.form_type).to be_nil
    end
  end

  describe 'encryption' do
    it 'encrypts request_payload' do
      submission = create(:form_intake_submission, request_payload: '{"key": "value"}')
      raw_value = submission.attributes_before_type_cast['request_payload_ciphertext']
      expect(raw_value).not_to eq('{"key": "value"}')
      expect(submission.request_payload).to eq('{"key": "value"}')
    end

    it 'encrypts response' do
      submission = create(:form_intake_submission, response: '{"status": "ok"}')
      raw_value = submission.attributes_before_type_cast['response_ciphertext']
      expect(raw_value).not_to eq('{"status": "ok"}')
      expect(submission.response).to eq('{"status": "ok"}')
    end

    it 'encrypts error_message' do
      submission = create(:form_intake_submission, error_message: 'Something went wrong')
      raw_value = submission.attributes_before_type_cast['error_message_ciphertext']
      expect(raw_value).not_to eq('Something went wrong')
      expect(submission.error_message).to eq('Something went wrong')
    end
  end

  describe '#log_status_change' do
    it 'writes to Rails.logger.info' do
      logger = double
      allow(Rails).to receive(:logger).and_return(logger)
      allow(logger).to receive(:info)
      submission = create(:form_intake_submission, aasm_state: 'pending')

      submission.submit!

      expect(logger).to have_received(:info)
    end

    it 'includes all relevant fields in log hash' do
      submission = create(:form_intake_submission, aasm_state: 'pending')
      expect(Rails.logger).to receive(:info).with(hash_including(
                                                    form_intake_submission_id: submission.id,
                                                    benefits_intake_uuid: submission.benefits_intake_uuid,
                                                    form_submission_id: submission.form_submission_id,
                                                    form_type: submission.form_type,
                                                    retry_count: submission.retry_count,
                                                    from_state: :pending,
                                                    to_state: :submitted,
                                                    event: :submit!,
                                                    message: 'Form Intake Submission submitted to GCIO'
                                                  ))
      submission.submit!
    end
  end
end
