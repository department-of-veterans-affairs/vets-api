# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::SubmitForm686cJob, type: :job do
  subject { described_class.new.perform(user.uuid, dependency_claim.id, vet_info) }

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

  before do
    allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(false)
  end

  context 'when it is a Thursday at 2AM UTC' do
    subject { described_class.perform_async(user.uuid, dependency_claim.id, vet_info) }

    before { Timecop.freeze(Time.zone.parse('2021-09-09T02:00:00Z')) }

    after { Timecop.return }

    it 'does not submit the 686' do
      client_stub = instance_double('BGS::Form686c')
      allow(BGS::Form686c).to receive(:new).with(an_instance_of(User)) { client_stub }
      expect(client_stub).not_to receive(:submit)

      subject
      described_class.perform_one
    end
  end

  it 'calls #submit for 686c submission' do
    client_stub = instance_double('BGS::Form686c')
    allow(BGS::Form686c).to receive(:new).with(an_instance_of(User)) { client_stub }
    expect(client_stub).to receive(:submit).once

    subject
  end

  it 'sends confirmation email' do
    client_stub = instance_double('BGS::Form686c')
    allow(BGS::Form686c).to receive(:new).with(an_instance_of(User)) { client_stub }
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
    it 'enqueues SubmitForm674Job' do
      allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
      client_stub = instance_double('BGS::Form686c')
      allow(BGS::Form686c).to receive(:new).with(an_instance_of(User)) { client_stub }
      expect(client_stub).to receive(:submit).once
      expect(BGS::SubmitForm674Job).to receive(:perform_async).with(user.uuid, dependency_claim.id, vet_info)

      subject
    end
  end

  context 'Claim is not submittable_674' do
    it 'does not enqueue SubmitForm674Job' do
      client_stub = instance_double('BGS::Form686c')
      allow(BGS::Form686c).to receive(:new).with(an_instance_of(User)) { client_stub }
      expect(client_stub).to receive(:submit).once
      expect(BGS::SubmitForm674Job).not_to receive(:perform_async)

      subject
    end
  end

  context 'when submission raises error' do
    it 'calls DependentsApplicationFailureMailer' do
      client_stub = instance_double('BGS::Form686c')
      mailer_double = double('Mail::Message')
      allow(BGS::Form686c).to receive(:new).with(an_instance_of(User)) { client_stub }
      expect(client_stub).to receive(:submit).and_raise(StandardError)

      allow(mailer_double).to receive(:deliver_now)
      expect(DependentsApplicationFailureMailer).to receive(:build).with(an_instance_of(User)) { mailer_double }

      subject
    end
  end
end
