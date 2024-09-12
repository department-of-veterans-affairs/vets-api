# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateVeteranSubmission, type: :service do
  describe '#call' do
    subject { described_class.new(va_gov_submission_id, va_gov_submission_type) }

    let(:va_gov_submission_id) { SecureRandom.alphanumeric(12) }
    let(:va_gov_submission_type) { 'MyString' }

    it 'creates a VeteranSubmission record' do
      expect { subject.call }.to change(VeteranSubmission, :count).by(1)
    end

    it 'sets the correct va_gov_submission_id' do
      veteran_submission = subject.call
      expect(veteran_submission.va_gov_submission_id).to eq(va_gov_submission_id)
    end

    it 'sets the correct va_gov_submission_type' do
      veteran_submission = subject.call
      expect(veteran_submission.va_gov_submission_type).to eq(va_gov_submission_type)
    end
  end
end
