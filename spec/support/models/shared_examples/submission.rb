# frozen_string_literal: true

shared_examples_for 'a Submission model' do
  it { is_expected.to validate_presence_of :form_id }

  describe 'encrypted attributes' do
    it 'responds to encrypted fields' do
      subject = described_class.new
      expect(subject).to respond_to(:reference_data)
    end
  end

  describe '#latest_attempt' do
    it 'returns the last attempt' do
      expect(subject.latest_attempt).to be_nil

      # subject at this point is an instance of the calling class
      submission = subject.class.create(form_id: 'TEST', saved_claim_id: 1)
      attempts = []
      5.times { attempts << submission.submission_attempts.create }

      expect(submission.submission_attempts.length).to eq 5
      expect(submission.latest_attempt).to eq attempts.last
    end
  end
end
