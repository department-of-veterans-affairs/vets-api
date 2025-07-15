# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DecisionHandler do
  let(:declined_subject) { build_subject('declined') }
  let(:accepted_subject) { build_subject('accepted') }
  let(:ptcpnt_id) { '600043284' }
  let(:proc_id) { '12345' }
  let(:representative_id) { '11' }
  let(:poa_code) { '087' }
  let(:metadata) do
    { 'veteran' => {
      'vnp_phone_id' => '106175', 'vnp_email_addr_id' => '148885', 'vnp_mailing_addr_id' => '148886'
    } }
  end
  let(:claimant_ptcpnt_id) { nil }

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
      ptcpnt_id:,
      proc_id:,
      representative_id:,
      poa_code:,
      metadata:,
      claimant_ptcpnt_id:
    )
  end
end
