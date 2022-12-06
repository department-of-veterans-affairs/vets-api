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
end
