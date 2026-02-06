# frozen_string_literal: true

require 'rails_helper'
require 'pcpg/monitor'

RSpec.describe Lighthouse::SubmitCareerCounselingJob do
  let(:claim) { create(:education_career_counseling_claim) }
  let(:job) { described_class.new }
  let(:monitor) { double('monitor') }
  let(:exhaustion_msg) do
    { 'args' => [], 'class' => 'Lighthouse::SubmitCareerCounselingJob', 'error_message' => 'An error occurred',
      'queue' => 'default' }
  end
  let(:user_account_uuid) { 123 }

  describe '#perform' do
    it 'sends to central mail' do
      expect_any_instance_of(SavedClaim::EducationCareerCounselingClaim).to receive(:send_to_benefits_intake!)

      job.perform(claim.id)
    end

    it 'sends confirmation email' do
      allow_any_instance_of(SavedClaim::EducationCareerCounselingClaim).to receive(:send_to_benefits_intake!)

      expect(job).to receive(:send_confirmation_email).with(nil)

      job.perform(claim.id)
    end
  end

  describe '#send_confirmation_email' do
    context 'user logged in' do
      let(:user) { create(:evss_user, :loa3) }

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

  describe 'sidekiq_retries_exhausted block with flipper on' do
    before do
      Flipper.enable(:form27_8832_action_needed_email) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      allow(PCPG::Monitor).to receive(:new).and_return(monitor)
      allow(monitor).to receive :track_submission_exhaustion
    end

    it 'logs error when retries are exhausted' do
      Lighthouse::SubmitCareerCounselingJob.within_sidekiq_retries_exhausted_block(
        { 'args' => [claim.id, user_account_uuid] }
      ) do
        expect(SavedClaim).to receive(:find).with(claim.id).and_return(claim)
        exhaustion_msg['args'] = [claim.id, user_account_uuid]
        expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim, 'foo@foo.com')
        expect(VANotify::EmailJob).to receive(:perform_async).with(
          'foo@foo.com',
          'form27_8832_action_needed_email_template_id',
          {
            'first_name' => 'DERRICK',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => claim.confirmation_number
          }
        )
      end
    end

    it 'logs error when retries are exhausted with no email' do
      Lighthouse::SubmitCareerCounselingJob.within_sidekiq_retries_exhausted_block(
        { 'args' => [claim.id, user_account_uuid] }
      ) do
        expect(SavedClaim).to receive(:find).with(claim.id).and_return(claim)
        exhaustion_msg['args'] = [claim.id, user_account_uuid]
        claim.parsed_form['claimantInformation'].delete('emailAddress')
        expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim, nil)
      end
    end
  end
end
