# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::SubmitForm674Job, type: :job do
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

  context 'The flipper is turned on' do
    before do
      Flipper.enable(:dependents_submit_674_independently)
    end

    it 'calls #submit for 674 submission' do
      client_stub = instance_double('BGS::Form674')
      allow(BGS::Form674).to receive(:new).with(an_instance_of(OpenStruct)) { client_stub }
      expect(client_stub).to receive(:submit).once

      described_class.new.perform(user.uuid, user.icn, dependency_claim.id, vet_info, user_struct.to_h)
    end

    it 'calls #submit without a user_struct passed in by 686c' do
      client_stub = instance_double('BGS::Form674')
      allow(BGS::Form674).to receive(:new).with(an_instance_of(OpenStruct)) { client_stub }
      expect(client_stub).to receive(:submit).once

      described_class.new.perform(user.uuid, user.icn, dependency_claim.id, vet_info)
    end

    it 'sends confirmation email' do
      client_stub = instance_double('BGS::Form674')
      allow(BGS::Form674).to receive(:new).with(an_instance_of(OpenStruct)) { client_stub }
      expect(client_stub).to receive(:submit).once

      expect(VANotify::EmailJob).to receive(:perform_async).with(
        user.va_profile_email,
        'fake_template_id',
        {
          'date' => Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y'),
          'first_name' => 'WESLEY'
        }
      )

      described_class.new.perform(user.uuid, user.icn, dependency_claim.id, vet_info, user_struct.to_h)
    end

    context 'error' do
      before do
        InProgressForm.create!(form_id: '686C-674', user_uuid: user.uuid, form_data: all_flows_payload)
      end

      it 'calls #submit for 674 submission' do
        job = described_class.new
        client_stub = instance_double('BGS::Form674')
        mailer_double = double('Mail::Message')
        allow(BGS::Form674).to receive(:new).with(an_instance_of(OpenStruct)) { client_stub }
        expect(client_stub).to receive(:submit).and_raise(StandardError)
        allow(mailer_double).to receive(:deliver_now)
        expect(DependentsApplicationFailureMailer).to receive(:build).with(an_instance_of(OpenStruct)) { mailer_double }
        expect(job).to receive(:salvage_save_in_progress_form).with('686C-674', user.uuid, anything)

        job.perform(user.uuid, user.icn, dependency_claim.id, vet_info, user_struct.to_h)
      end
    end
  end

  context 'The flipper is turned off' do
    before do
      Flipper.disable(:dependents_submit_674_independently)
    end

    it 'calls #submit for 674 submission' do
      client_stub = instance_double('BGS::Form674')
      allow(BGS::Form674).to receive(:new).with(an_instance_of(OpenStruct)) { client_stub }
      expect(client_stub).to receive(:submit).once

      described_class.new.perform(user.uuid, user.icn, dependency_claim.id, vet_info, user_struct.to_h)
    end

    it 'sends confirmation email' do
      client_stub = instance_double('BGS::Form674')
      allow(BGS::Form674).to receive(:new).with(an_instance_of(OpenStruct)) { client_stub }
      expect(client_stub).to receive(:submit).once

      expect(VANotify::EmailJob).to receive(:perform_async).with(
        user.va_profile_email,
        'fake_template_id',
        {
          'date' => Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y'),
          'first_name' => 'WESLEY'
        }
      )

      described_class.new.perform(user.uuid, user.icn, dependency_claim.id, vet_info, user_struct.to_h)
    end

    context 'error' do
      before do
        InProgressForm.create!(form_id: '686C-674', user_uuid: user.uuid, form_data: all_flows_payload)
      end

      it 'calls #submit for 674 submission' do
        job = described_class.new
        client_stub = instance_double('BGS::Form674')
        mailer_double = double('Mail::Message')
        allow(BGS::Form674).to receive(:new).with(an_instance_of(OpenStruct)) { client_stub }
        expect(client_stub).to receive(:submit).and_raise(StandardError)
        allow(mailer_double).to receive(:deliver_now)
        expect(DependentsApplicationFailureMailer).to receive(:build).with(an_instance_of(OpenStruct)) { mailer_double }
        expect(job).to receive(:salvage_save_in_progress_form).with('686C-674', user.uuid, anything)

        job.perform(user.uuid, user.icn, dependency_claim.id, vet_info, user_struct.to_h)
      end
    end
  end
end
