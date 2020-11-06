# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::SubmitForm674Job, type: :job do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:dependency_claim) { create(:dependency_claim) }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674) }
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

  context 'error' do
    it 'calls #submit for 674 submission' do
      client_stub = instance_double('BGS::Form674')
      mailer_double = double('Mail::Message')
      allow(BGS::Form674).to receive(:new).with(an_instance_of(User)) { client_stub }
      expect(client_stub).to receive(:submit).and_raise(StandardError)

      allow(mailer_double).to receive(:deliver_later)
      expect(DependentsApplicationFailureMailer).to receive(:build).with(an_instance_of(User)) { mailer_double }

      described_class.new.perform(user.uuid, dependency_claim.id, vet_info)
    end
  end
end
