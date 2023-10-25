# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::SubmitForm686cEncryptedJob, type: :job do
  subject do
    described_class.new.perform(user.uuid, user.icn, dependency_claim.id,
                                KmsEncrypted::Box.new.encrypt(vet_info.to_json))
  end

  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:dependency_claim) { create(:dependency_claim) }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674_kitchen_sink) }
  let(:birth_date) { '1809-02-12' }
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
  let(:user_struct) do
    OpenStruct.new(
      first_name: vet_info['veteran_information']['full_name']['first'],
      last_name: vet_info['veteran_information']['full_name']['last'],
      middle_name: vet_info['veteran_information']['full_name']['middle'],
      ssn: vet_info['veteran_information']['ssn'],
      email: vet_info['veteran_information']['email'],
      va_profile_email: vet_info['veteran_information']['va_profile_email'],
      participant_id: vet_info['veteran_information']['participant_id'],
      icn: vet_info['veteran_information']['icn'],
      uuid: vet_info['veteran_information']['uuid'],
      common_name: vet_info['veteran_information']['common_name']
    )
  end

  before do
    allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(false)
  end

  it 'calls #submit for 686c submission' do
    client_stub = instance_double(BGS::Form686c)
    allow(BGS::Form686c).to receive(:new).with(an_instance_of(OpenStruct)) { client_stub }
    expect(client_stub).to receive(:submit).once

    subject
  end

  it 'sends confirmation email' do
    client_stub = instance_double(BGS::Form686c)
    allow(BGS::Form686c).to receive(:new).with(an_instance_of(OpenStruct)) { client_stub }
    expect(client_stub).to receive(:submit).once

    expect(VANotify::EmailJob).to receive(:perform_async).with(
      user.va_profile_email,
      'fake_template_id',
      {
        'date' => Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y'),
        'first_name' => 'WESLEY'
      }
    )

    subject
  end

  context 'Claim is submittable_674' do
    it 'enqueues SubmitForm674EncryptedJob' do
      allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
      client_stub = instance_double(BGS::Form686c)
      allow(BGS::Form686c).to receive(:new).with(an_instance_of(OpenStruct)) { client_stub }
      expect(client_stub).to receive(:submit).once
      expect(BGS::SubmitForm674EncryptedJob).to receive(:perform_async).with(user.uuid,
                                                                             user.icn,
                                                                             dependency_claim.id,
                                                                             an_instance_of(String),
                                                                             an_instance_of(String))

      subject
    end
  end

  context 'Claim is not submittable_674' do
    it 'does not enqueue SubmitForm674Job' do
      client_stub = instance_double(BGS::Form686c)
      allow(BGS::Form686c).to receive(:new).with(an_instance_of(OpenStruct)) { client_stub }
      expect(client_stub).to receive(:submit).once
      expect(BGS::SubmitForm674Job).not_to receive(:perform_async)

      subject
    end
  end

  context 'when submission raises error with central mail flipper on' do
    before do
      Flipper.enable(:dependents_central_submission)
    end

    it 'calls DependentsApplicationFailureMailer' do
      client_stub = instance_double(BGS::Form686c)
      allow(BGS::Form686c).to receive(:new).with(an_instance_of(OpenStruct)) { client_stub }
      expect(client_stub).to receive(:submit).and_raise(StandardError)

      expect(CentralMail::SubmitCentralForm686cJob).to receive(:perform_async).with(dependency_claim.id,
                                                                                    an_instance_of(String),
                                                                                    an_instance_of(String))
      subject
    end
  end

  context 'when submission raises error with flipper off' do
    before do
      Flipper.disable(:dependents_central_submission)
    end

    it 'calls DependentsApplicationFailureMailer' do
      client_stub = instance_double(BGS::Form686c)
      mailer_double = double('Mail::Message')
      allow(BGS::Form686c).to receive(:new).with(an_instance_of(OpenStruct)) { client_stub }
      expect(client_stub).to receive(:submit).and_raise(StandardError)

      allow(mailer_double).to receive(:deliver_now)
      expect(DependentsApplicationFailureMailer).to receive(:build).with(an_instance_of(OpenStruct)) { mailer_double }

      subject
    end
  end
end
