# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CentralMail::SubmitCareerCounselingJob do
  let(:claim) { create(:education_career_counseling_claim) }
  let(:job) { described_class.new }

  describe '#perform' do
    it 'sends to central mail' do
      expect_any_instance_of(SavedClaim::EducationCareerCounselingClaim).to receive(:send_to_central_mail!)

      job.perform(claim.id)
    end

    it 'sends confirmation email' do
      allow_any_instance_of(SavedClaim::EducationCareerCounselingClaim).to receive(:send_to_central_mail!)

      expect(job).to receive(:send_confirmation_email).with(nil)

      job.perform(claim.id)
    end
  end

  describe '#send_confirmation_email' do
    context 'user logged in' do
      let(:user) { FactoryBot.create(:evss_user, :loa3) }

      it 'calls the VA notify email job with the user email' do
        expect(VANotify::EmailJob).to receive(:perform_async).with(
          user.va_profile_email,
          'career_counseling_confirmation_email_template_id',
          {
            'date' => Time.zone.today.strftime('%B %d, %Y'),
            'first_name' => 'DERRICK'
          }
        )

        job.instance_variable_set(:@claim, claim)
        job.send_confirmation_email(user.uuid)
      end
    end

    context 'user not logged in' do
      it 'calls the VA notify email job with the claimant email' do
        expect(VANotify::EmailJob).to receive(:perform_async).with(
          'foo@foo.com',
          'career_counseling_confirmation_email_template_id',
          {
            'date' => Time.zone.today.strftime('%B %d, %Y'),
            'first_name' => 'DERRICK'
          }
        )

        job.instance_variable_set(:@claim, claim)
        job.send_confirmation_email(nil)
      end
    end
  end
end
