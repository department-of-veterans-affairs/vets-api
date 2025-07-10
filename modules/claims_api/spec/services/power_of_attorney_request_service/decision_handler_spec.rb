# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DecisionHandler do
  subject { described_class.new(decision:, ptcpnt_id:, proc_id:, representative_id:) }

  let(:decision) { 'declined' }
  let(:ptcpnt_id) { '600043284' }
  let(:proc_id) { '12345' }
  let(:representative_id) { '11' }

  context "When the decision is 'Declined'" do
    it 'calls the declined decision service handler' do
      expect_any_instance_of(ClaimsApi::PowerOfAttorneyRequestService::DeclinedDecisionHandler).to receive(:call)

      subject.call
    end
  end
end
