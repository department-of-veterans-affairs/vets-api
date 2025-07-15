# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DecisionHandler do
  let(:veteran) do
    OpenStruct.new(
      icn: '1012861229V078999',
      first_name: 'Ralph',
      last_name: 'Lee',
      middle_name: nil,
      birth_date: '1948-10-30',
      loa: { current: 3, highest: 3 },
      edipi: nil,
      ssn: '796378782',
      participant_id: '600043284',
      mpi: OpenStruct.new(
        icn: '1012861229V078999',
        profile: OpenStruct.new(ssn: '796378782')
      )
    )
  end
  let(:proc_id) { '12345' }
  let(:registration_number) { '11' }
  let(:poa_code) { '087' }
  let(:metadata) do
    { 'veteran' => {
      'vnp_phone_id' => '106175', 'vnp_email_addr_id' => '148885', 'vnp_mailing_addr_id' => '148886'
    } }
  end
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD

=======
>>>>>>> 421a7105da (API-43735-gather-data-for-poa-accept-phone-3)
  let(:claimant) { nil }

  let(:declined_subject) { build_subject('declined') }
  let(:accepted_subject) { build_subject('accepted') }
<<<<<<< HEAD

  let(:claimant_ptcpnt_id) { nil }
=======
>>>>>>> 421a7105da (API-43735-gather-data-for-poa-accept-phone-3)
=======
  let(:claimant_ptcpnt_id) { nil }
>>>>>>> 58184e4087 (API-43735-gather-data-for-poa-accept-2)
=======
  let(:claimant_ptcpnt_id) { nil }
>>>>>>> 56a1343d6f (API-43735-gather-data-for-poa-accept-2)
=======
  let(:claimant_ptcpnt_id) { nil }
>>>>>>> efdc6de40f (API-43735-gather-data-for-poa-accept-2)

  context "When the decision is 'Declined'" do
    it 'calls the declined decision service handler' do
      expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::DeclinedDecisionHandler).to receive(:call)

      declined_subject.call
    end
  end

  context "When the decision is 'Accepted'" do
    it 'calls the accepted decision service handler' do
      expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler).to receive(:call)

      accepted_subject.call
    end
  end

  private

  def build_subject(decision)
    described_class.new(
      decision:,
      proc_id:,
      registration_number:,
      poa_code:,
      metadata:,
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
      veteran:,
      claimant:
=======
      claimant_ptcpnt_id:
>>>>>>> 58184e4087 (API-43735-gather-data-for-poa-accept-2)
=======
      claimant_ptcpnt_id:
>>>>>>> 56a1343d6f (API-43735-gather-data-for-poa-accept-2)
=======
      claimant_ptcpnt_id:
>>>>>>> efdc6de40f (API-43735-gather-data-for-poa-accept-2)
    )
  end
end
