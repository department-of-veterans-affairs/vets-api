# frozen_string_literal: true

shared_examples_for 'a Submission model' do
  it { is_expected.to validate_presence_of :form_id }

  describe 'encrypted attributes' do
    it 'responds to encrypted fields' do
      subject = described_class.new
      expect(subject).to respond_to(:reference_data)
    end
  end
end
