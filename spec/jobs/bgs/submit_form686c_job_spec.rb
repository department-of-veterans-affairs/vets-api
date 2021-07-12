# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::SubmitForm686cJob, type: :job do
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

  it 'calls #submit for 686c submission' do
    client_stub = instance_double('BGS::Form686c')
    allow(BGS::Form686c).to receive(:new).with(an_instance_of(User)) { client_stub }
    expect(client_stub).to receive(:submit).once
    expect_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_686?).and_return(true)
    expect_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(false)

    described_class.new.perform(user.uuid, dependency_claim.id, vet_info)
  end

  context 'error' do
    it 'calls #submit for 686c submission' do
      client_stub = instance_double('BGS::Form686c')
      mailer_double = double('Mail::Message')
      allow(BGS::Form686c).to receive(:new).with(an_instance_of(User)) { client_stub }
      expect(client_stub).to receive(:submit).and_raise(StandardError)
      expect_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_686?).and_return(true)
      expect_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(false)

      allow(mailer_double).to receive(:deliver_now)
      expect(DependentsApplicationFailureMailer).to receive(:build).with(an_instance_of(User)) { mailer_double }

      described_class.new.perform(user.uuid, dependency_claim.id, vet_info)
    end
  end
end
