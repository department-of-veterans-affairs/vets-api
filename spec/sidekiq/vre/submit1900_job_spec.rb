# frozen_string_literal: true

require 'rails_helper'

describe VRE::Submit1900Job do
  let(:user_struct) do
    OpenStruct.new(
      edipi: '1007697216',
      birls_id: '796043735',
      participant_id: '600061742',
      pid: '600061742',
      birth_date: '1986-05-06T00:00:00+00:00'.to_date,
      ssn: '796043735',
      vet360_id: '1781151',
      loa3?: true,
      icn: '1013032368V065534',
      uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef',
      va_profile_email: 'test@test.com'
    )
  end
  let(:encrypted_user) { KmsEncrypted::Box.new.encrypt(user_struct.to_h.to_json) }
  let(:user) { OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user))) }

  let(:monitor) { double('monitor') }
  let(:exhaustion_msg) do
    { 'args' => [], 'class' => 'VRE::Submit1900Job', 'error_message' => 'An error occurred',
      'queue' => 'default' }
  end

  %w[v1 v2].each do |form_type|
    context "with #{form_type}" do
      describe '#perform' do
        subject { described_class.new.perform(claim.id, encrypted_user) }

        let(:claim) { create_claim(form_type) }

        before do
          allow(SavedClaim::VeteranReadinessEmploymentClaim).to receive(:find).and_return(claim)
        end

        after do
          subject
        end

        it 'calls claim.add_claimant_info' do
          allow(claim).to receive(:send_to_lighthouse!)
          allow(claim).to receive(:send_to_res)

          expect(claim).to receive(:add_claimant_info).with(user)
        end

        it 'calls claim.send_to_vre' do
          expect(claim).to receive(:send_to_vre).with(user)
        end
      end

      describe 'raises an exception with email flipper on' do
        let(:claim) { create_claim(form_type) }

        before do
          allow(SavedClaim::VeteranReadinessEmploymentClaim).to receive(:find).and_return(claim)
          allow(VRE::Monitor).to receive(:new).and_return(monitor)
          allow(monitor).to receive :track_submission_exhaustion
          allow(Flipper).to receive(:enabled?).with(:vre_trigger_action_needed_email).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:vre_use_new_vfs_notification_library).and_return(false)
        end

        it 'when queue is exhausted' do
          VRE::Submit1900Job.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, encrypted_user] }) do
            exhaustion_msg['args'] = [claim.id, encrypted_user]
            expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim.parsed_form['email'])
            expect(VANotify::EmailJob).to receive(:perform_async).with(
              form_type == 'v1' ? 'test@gmail.xom' : 'email@test.com',
              'form1900_action_needed_email_template_id',
              {
                'first_name' => form_type == 'v1' ? 'Homer' : 'First',
                'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                'confirmation_number' => claim.confirmation_number
              }
            )
          end
        end
      end

      [true, false].each do |feature_flag_state|
        context "when vre_use_new_vfs_notification_library is #{feature_flag_state}" do
          let(:claim) { create_claim(form_type) }

          before do
            allow(SavedClaim::VeteranReadinessEmploymentClaim).to receive(:find).and_return(claim)
            allow(feature_flag_state ? VRE::VREMonitor : VRE::Monitor).to receive(:new).and_return(monitor)
            allow(monitor).to receive :track_submission_exhaustion
            user_struct.va_profile_email = nil
            allow(Flipper).to receive(:enabled?)
              .with(:vre_trigger_action_needed_email)
              .and_return(true)
            allow(Flipper).to receive(:enabled?)
              .with(:vre_use_new_vfs_notification_library)
              .and_return(feature_flag_state)
          end

          describe 'when queue is exhausted with no email' do
            it 'tracks submission exhaustion with appropriate arguments' do
              VRE::Submit1900Job.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, encrypted_user] }) do
                expect(SavedClaim).to receive(:find).with(claim.id).and_return(claim)
                claim.parsed_form.delete('email')

                exhaustion_msg['args'] = [claim.id, encrypted_user]
                if feature_flag_state
                  expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim)
                else
                  expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
                end
              end
            end
          end
        end
      end
    end
  end

  def create_claim(form_type)
    if form_type == 'v1'
      create(:veteran_readiness_employment_claim)
    else
      create(:new_veteran_readiness_employment_claim)
    end
  end
end
