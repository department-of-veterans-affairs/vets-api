# frozen_string_literal: true

require 'rails_helper'
require 'vre/notification_email'
require 'vre/vre_monitor'

describe VRE::Submit1900Job do
  let(:job) { described_class.new }
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
  let(:notification) { instance_double(VRE::NotificationEmail) }
  let(:msg) { { 'args' => [claim.id, encrypted_user] } }
  let(:vre_monitor) { instance_double(VRE::VREMonitor) }
  let(:legacy_monitor) { instance_double(VRE::Monitor) }

  let(:exhaustion_msg) do
    { 'args' => [], 'class' => 'VRE::Submit1900Job', 'error_message' => 'An error occurred',
      'queue' => 'default' }
  end

  %w[v1 v2].each do |form_type|
    context "with #{form_type}" do
      let(:claim) { create_claim(form_type) }

      before do
        allow(SavedClaim::VeteranReadinessEmploymentClaim).to receive(:find).and_return(claim)
        allow(Flipper).to receive(:enabled?)
          .with(:vre_trigger_action_needed_email)
          .and_return(true)
      end

      describe 'Notifications - using new VFS library' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:vre_use_new_vfs_notification_library)
            .and_return(true)
          allow(VRE::VREMonitor).to receive(:new).and_return(vre_monitor)
          allow(job).to receive(:monitor).and_return(vre_monitor)
        end

        it 'uses VFS New NotificationEmail when retries are exhausted' do
          expect(vre_monitor).to receive(:track_submission_exhaustion).with(msg, claim)
          described_class.trigger_failure_events(msg)
        end
      end

      describe 'Notifications - using legacy fire-and-forget strategy' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:vre_use_new_vfs_notification_library)
            .and_return(false)
          allow(VRE::Monitor).to receive(:new).and_return(legacy_monitor)
          allow(job).to receive(:monitor).and_return(legacy_monitor)
          allow(legacy_monitor).to receive :track_submission_exhaustion
        end

        describe 'email exception handling' do
          it 'when queue is exhausted' do
            VRE::Submit1900Job.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, encrypted_user] }) do
              exhaustion_msg['args'] = [claim.id, encrypted_user]
              expect(legacy_monitor).to receive(:track_submission_exhaustion)
                .with(exhaustion_msg, claim.parsed_form['email'])
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

          it 'when queue is exhausted with no email' do
            user_struct.va_profile_email = nil
            VRE::Submit1900Job.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, encrypted_user] }) do
              expect(SavedClaim).to receive(:find).with(claim.id).and_return(claim)
              exhaustion_msg['args'] = [claim.id, encrypted_user]
              claim.parsed_form.delete('email')
              expect(legacy_monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
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
