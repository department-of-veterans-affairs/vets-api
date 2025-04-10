# frozen_string_literal: true

require 'rails_helper'

describe VRE::VRESubmit1900Job do
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
  let(:claim) { create(:veteran_readiness_employment_claim) }

  let(:monitor) { double('VRE::VREMonitor') }
  let(:exhaustion_msg) do
    { 'args' => [], 'class' => 'VRE::VRESubmit1900Job', 'error_message' => 'An error occurred',
      'queue' => 'default' }
  end

  describe '#perform' do
    subject { described_class.new.perform(claim.id, encrypted_user) }

    before do
      allow(VRE::VREVeteranReadinessEmploymentClaim).to receive(:find).and_return(claim)
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

  describe 'queue exhaustion' do
    before do
      allow(VRE::VREVeteranReadinessEmploymentClaim).to receive(:find).and_return(claim)
      allow(VRE::VREMonitor).to receive(:new).and_return(monitor)
      allow(monitor).to receive :track_submission_exhaustion
      Flipper.enable(:vre_trigger_action_needed_email)
    end

    context 'when email is present' do
      it 'raises an exception and sends email to user' do
        VRE::VRESubmit1900Job.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, encrypted_user] }) do
          expect(SavedClaim).to receive(:find).with(claim.id).and_return(claim)
          exhaustion_msg['args'] = [claim.id, encrypted_user]
          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, claim.parsed_form['email'])
          expect(VANotify::EmailJob).to receive(:perform_async).with(
            'test@gmail.xom',
            'form1900_action_needed_email_template_id',
            {
              'first_name' => 'Homer',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => claim.confirmation_number
            }
          )
        end
      end
    end

    context 'when email is not present' do
      it 'raises an exception and sends no email' do
        user_struct.va_profile_email = nil

        VRE::VRESubmit1900Job.within_sidekiq_retries_exhausted_block({ 'args' => [claim.id, encrypted_user] }) do
          expect(SavedClaim).to receive(:find).with(claim.id).and_return(claim)
          exhaustion_msg['args'] = [claim.id, encrypted_user]
          claim.parsed_form.delete('email')
          expect(monitor).to receive(:track_submission_exhaustion).with(exhaustion_msg, nil)
          expect(VANotify::EmailJob).not_to receive(:perform_async)
        end
      end
    end
  end
end
