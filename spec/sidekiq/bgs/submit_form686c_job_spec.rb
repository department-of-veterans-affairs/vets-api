# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/job_retry'

RSpec.describe BGS::SubmitForm686cJob, type: :job do
  let(:job) { subject.perform(user.uuid, user.icn, dependency_claim.id, encrypted_vet_info) }
  let(:user) { create(:evss_user, :loa3) }
  let(:dependency_claim) { create(:dependency_claim) }
  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }
  let(:birth_date) { '1809-02-12' }
  let(:client_stub) { instance_double(BGS::Form686c) }
  let(:vet_info) do
    {
      'veteran_information' => {
        'full_name' => {
          'first' => 'WESLEY', 'middle' => nil, 'last' => 'FORD'
        },
        'common_name' => user.common_name,
        'participant_id' => '600061742',
        'uuid' => user.uuid,
        'email' => user.email,
        'va_profile_email' => user.va_profile_email,
        'ssn' => '796043735',
        'va_file_number' => '796043735',
        'icn' => user.icn,
        'birth_date' => birth_date
      }
    }
  end
  let(:encrypted_vet_info) { KmsEncrypted::Box.new.encrypt(vet_info.to_json) }
  let(:user_struct) do
    nested_info = vet_info['veteran_information']
    OpenStruct.new(
      first_name: nested_info['full_name']['first'],
      last_name: nested_info['full_name']['last'],
      middle_name: nested_info['full_name']['middle'],
      ssn: nested_info['ssn'],
      email: nested_info['email'],
      va_profile_email: nested_info['va_profile_email'],
      participant_id: nested_info['participant_id'],
      icn: nested_info['icn'],
      uuid: nested_info['uuid'],
      common_name: nested_info['common_name']
    )
  end

  before do
    allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(false)
    allow(OpenStruct).to receive(:new)
      .with(hash_including(icn: vet_info['veteran_information']['icn']))
      .and_return(user_struct)
  end

  context 'successfully' do
    it 'calls #submit for 686c submission' do
      expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
      expect(client_stub).to receive(:submit).once

      expect { job }.not_to raise_error
    end

    context 'with separate emails by form' do
      it 'sends confirmation email for 686c only' do
        expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
        expect(client_stub).to receive(:submit).once
        allow(Flipper).to receive(:enabled?).with(:dependents_separate_confirmation_email).and_return(true)

        expect(VANotify::EmailJob).to receive(:perform_async).with(
          user.va_profile_email,
          'fake_received686',
          { 'confirmation_number' => dependency_claim.confirmation_number,
            'date_submitted' => Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y'),
            'first_name' => 'WESLEY' },
          'fake_secret',
          { callback_klass: 'VeteranFacingServices::NotificationCallback::SavedClaim',
            callback_metadata: { email_template_id: 'fake_received686',
                                 email_type: :received686,
                                 form_id: '686C-674',
                                 saved_claim_id: dependency_claim.id,
                                 service_name: 'dependents' } }
        )

        expect { job }.not_to raise_error
      end

      it 'does not send confirmation email for 686c_674 combo' do
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
        expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
        expect(client_stub).to receive(:submit).once
        allow(Flipper).to receive(:enabled?).with(:dependents_separate_confirmation_email).and_return(true)

        expect(VANotify::EmailJob).not_to receive(:perform_async)

        expect { job }.not_to raise_error
      end
    end

    context 'without separate emails by form' do
      it 'sends confirmation email' do
        expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
        expect(client_stub).to receive(:submit).once
        allow(Flipper).to receive(:enabled?).with(:dependents_separate_confirmation_email).and_return(false)

        expect(VANotify::EmailJob).to receive(:perform_async).with(
          user.va_profile_email,
          'fake_template_id',
          {
            'date' => Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y'),
            'first_name' => 'WESLEY'
          }
        )

        expect { job }.not_to raise_error
      end
    end

    context 'Claim is submittable_674' do
      it 'enqueues SubmitForm674Job' do
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
        expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
        expect(client_stub).to receive(:submit).once
        expect(BGS::SubmitForm674Job).to receive(:perform_async).with(user.uuid, user.icn,
                                                                      dependency_claim.id, encrypted_vet_info,
                                                                      an_instance_of(String))

        expect { job }.not_to raise_error
      end
    end

    context 'Claim is not submittable_674' do
      it 'does not enqueue SubmitForm674Job' do
        expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
        expect(client_stub).to receive(:submit).once
        expect(BGS::SubmitForm674Job).not_to receive(:perform_async)

        expect { job }.not_to raise_error
      end
    end
  end

  context 'when submission raises error' do
    it 'raises error' do
      expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
      expect(client_stub).to receive(:submit).and_raise(BGS::SubmitForm686cJob::Invalid686cClaim)

      expect { job }.to raise_error(BGS::SubmitForm686cJob::Invalid686cClaim)
    end

    it 'filters based on error cause' do
      expect(BGS::Form686c).to receive(:new).with(user_struct, dependency_claim).and_return(client_stub)
      expect(client_stub).to receive(:submit) { raise_nested_err }

      expect { job }.to raise_error(Sidekiq::JobRetry::Skip)
    end
  end
end

def raise_nested_err
  raise BGS::SubmitForm686cJob::Invalid686cClaim, 'A very specific error occurred: insertBenefitClaim: Invalid zipcode.'
rescue
  raise BGS::SubmitForm686cJob::Invalid686cClaim, 'A Generic Error Occurred'
end
