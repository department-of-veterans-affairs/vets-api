# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateVeteranSubmission, type: :service do
  describe '#call' do
    subject { described_class.new(va_gov_submission_id, va_gov_submission_type) }

    let(:va_gov_submission_id) { SecureRandom.alphanumeric(12) }
    let(:va_gov_submission_type) { 'MyString' }

    context 'when the VeteranSubmission does not exist' do
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

      it 'sets the status to created' do
        veteran_submission = subject.call
        expect(veteran_submission.status).to eq('created')
      end
    end

    context 'when the VeteranSubmission already exists' do
      before do
        VeteranSubmission.create!(
          va_gov_submission_id: va_gov_submission_id,
          va_gov_submission_type: va_gov_submission_type,
          status: :created
        )
      end

      it 'does not create a new VeteranSubmission record' do
        expect { subject.call }.not_to change(VeteranSubmission, :count)
      end

      it 'returns the existing VeteranSubmission record' do
        veteran_submission = subject.call
        expect(veteran_submission.va_gov_submission_id).to eq(va_gov_submission_id)
        expect(veteran_submission.va_gov_submission_type).to eq(va_gov_submission_type)
        expect(veteran_submission.status).to eq('created')
      end
    end
  end
end
