# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UpdateVeteranSubmission, type: :service do
  describe '#call' do
    subject do
      described_class.new(
        job_id: job_id,
        submission_type: submission_type,
        status: status,
        upstream_system_name: upstream_system_name,
        upstream_submission_id: upstream_submission_id
      )
    end

    let(:job_id) { SecureRandom.alphanumeric(12) }
    let(:submission_type) { 'MyString' }
    let(:status) { :succeeded }
    let(:upstream_system_name) { 'some_system' }
    let(:upstream_submission_id) { 'some_submission_id' }

    context 'when the VeteranSubmission exists' do
      let!(:veteran_submission) do
        VeteranSubmission.create!(
          va_gov_submission_id: job_id,
          va_gov_submission_type: submission_type,
          status: :succeeded
        )
      end

      it 'updates the status' do
        subject.call
        expect(veteran_submission.reload.status).to eq(status)
      end

      it 'updates the upstream_system_name' do
        subject.call
        expect(veteran_submission.reload.upstream_system_name).to eq(upstream_system_name)
      end

      it 'updates the upstream_submission_id' do
        subject.call
        expect(veteran_submission.reload.upstream_submission_id).to eq(upstream_submission_id)
      end
    end

    context 'when the VeteranSubmission does not exist' do
      it 'does not raise an error' do
        expect { subject.call }.not_to raise_error
      end

      it 'does not update any record' do
        expect { subject.call }.not_to change { VeteranSubmission.count }
      end
    end
  end
end
