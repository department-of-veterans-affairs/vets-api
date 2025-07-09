# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler do
  subject { described_class.new(ptcpnt_id:, proc_id:, poa_code:, metadata:, claimant_ptcpnt_id:) }

  let(:ptcpnt_id) { '600043284' }
  let(:proc_id) { '12345' }
  let(:poa_code) { '087' }
  let(:claimant_ptcpnt_id) {}
  let(:metadata) do
    {"vnp_phone_id"=>"106175", "vnp_email_addr_id"=>"148885", "vnp_mailing_addr_id"=>"148886"}
  end


  context 'Gathering all the required POA data' do
    it 'successfully calls the service' do
      expect(subject).to receive(:gather_poa_data)

      subject.call
    end
  end
end