# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RrdMasNotificationMailer, type: [:mailer] do
  let(:email) do
    described_class.build(submission)
  end

  context 'when building an email with a disability name and diagnostic code' do
    let(:submission) { create(:form526_submission, :with_everything) }

    it 'includes the DC but not the name in the body' do
      expect(email.body).to include('9999')
      expect(email.body).not_to include('PTSD')
    end
  end
end
