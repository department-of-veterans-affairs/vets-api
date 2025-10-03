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
  let(:claimant) { nil }

  let(:declined_decision) { 'declined' }
  let(:accepted_decision) { 'accepted' }
  let(:declined_subject) { build_subject(declined_decision) }
  let(:accepted_subject) { build_subject(accepted_decision) }

  context "When the decision is 'Declined'" do
    it 'calls the declined decision service handler' do
      expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::DeclinedDecisionHandler).to receive(:call)

      declined_subject.call
    end

    it 'returns an empty array' do
      allow_any_instance_of(
        ClaimsApi::PowerOfAttorneyRequestService::DeclinedDecisionHandler
      ).to receive(:call).and_return(anything)

      res = declined_subject.call

      expect(res).to eq([])
    end
  end

  context "When the decision is 'Accepted'" do
    let(:data) { { 'data' => { 'attributes' => { 'id' => '123' } } } }
    let(:type) { '2122' }

    it 'calls the accepted decision service handler' do
      expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler).to receive(:call)

      accepted_subject.call
    end

    it 'returns an array of values' do
      allow_any_instance_of(
        ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler
      ).to receive(:call).and_return([data, type])

      res = accepted_subject.call

      expect(res).to eq([data, type])
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
      veteran:,
      claimant:
    )
  end
end
