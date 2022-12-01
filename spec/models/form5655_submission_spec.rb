# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form5655Submission do
  describe '.submit_to_vba' do
    let(:form5655_submission) { create(:form5655_submission) }

    it 'enqueues a VBA submission job' do
      expect { form5655_submission.submit_to_vba }.to change(Form5655::VBASubmissionJob.jobs, :size).by(1)
    end
  end

  describe '.submit_to_vha' do
    let(:form5655_submission) { create(:form5655_submission) }

    it 'enqueues a VHA submission job' do
      expect { form5655_submission.submit_to_vha }.to change(Form5655::VHASubmissionJob.jobs, :size).by(1)
    end
  end

  describe '.add_form_properties' do
    let(:form5655_submission) { build(:form5655_submission) }

    it 'adds transactionId' do
      form5655_submission.save
      expect(form5655_submission.form['transactionId']).to eq(form5655_submission.id)
    end

    it 'sets a timestamp' do
      form5655_submission.save
      expect(form5655_submission.form['timestamp']).not_to be_nil
    end
  end
end
