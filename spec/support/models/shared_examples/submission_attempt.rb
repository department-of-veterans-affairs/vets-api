# frozen_string_literal: true

shared_examples_for 'a SubmissionAttempt model' do
  it { is_expected.to validate_presence_of :submission }

  describe 'associations' do
    it { expect(subject).to belong_to(:submission) }

    it { is_expected.to have_one(:saved_claim).through(:submission) }
  end

  describe 'encrypted attributes' do
    it 'responds to encrypted fields' do
      subject = described_class.new
      expect(subject).to respond_to(:metadata)
      expect(subject).to respond_to(:error_message)
      expect(subject).to respond_to(:response)
    end
  end
end
