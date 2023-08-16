# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::SubmitForm674Job, type: :job do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:dependency_claim) { create(:dependency_claim) }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674_kitchen_sink) }
  let(:vet_info) do
    {
      'veteran_information' => {
        'birth_date' => '1809-02-12',
        'full_name' => {
          'first' => 'WESLEY', 'last' => 'FORD', 'middle' => nil
        },
        'ssn' => '796043735',
        'va_file_number' => '796043735'
      }
    }
  end

  it 'calls #submit for 674 submission' do
    client_stub = instance_double('BGS::Form674')
    allow(BGS::Form674).to receive(:new).with(an_instance_of(User)) { client_stub }
    expect(client_stub).to receive(:submit).once

    described_class.new.perform(user.uuid, dependency_claim.id, vet_info)
  end

  it 'sends confirmation email' do
    client_stub = instance_double('BGS::Form674')
    allow(BGS::Form674).to receive(:new).with(an_instance_of(User)) { client_stub }
    expect(client_stub).to receive(:submit).once

    expect(VANotify::EmailJob).to receive(:perform_async).with(
      user.va_profile_email,
      'fake_template_id',
      {
        'date' => Time.now.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y'),
        'first_name' => 'WESLEY'
      }
    )

    described_class.new.perform(user.uuid, dependency_claim.id, vet_info)
  end

  context 'error' do
    before do
      InProgressForm.create!(form_id: '686C-674', user_uuid: user.uuid, form_data: all_flows_payload)
    end

    it 'calls #submit for 674 submission' do
      job = described_class.new
      client_stub = instance_double('BGS::Form674')
      mailer_double = double('Mail::Message')
      allow(BGS::Form674).to receive(:new).with(an_instance_of(User)) { client_stub }
      expect(client_stub).to receive(:submit).and_raise(StandardError)
      allow(mailer_double).to receive(:deliver_now)
      expect(DependentsApplicationFailureMailer).to receive(:build).with(an_instance_of(User)) { mailer_double }
      expect(job).to receive(:salvage_save_in_progress_form).with('686C-674', user.uuid, anything)

      job.perform(user.uuid, dependency_claim.id, vet_info)
    end
  end
end
