# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/manage_representative_service'

describe ClaimsApi::PowerOfAttorneyRequestService::DeclinedDecisionHandler do
  subject { described_class.new(ptcpnt_id:, proc_id:, representative_id:) }

  let(:ptcpnt_id) { '600043284' }
  let(:proc_id) { '12345' }
  let(:representative_id) { '11' }

  let(:poa_request_response) do
    {
      'poaRequestRespondReturnVOList' => [
        {
          'procID' => proc_id,
          'claimantFirstName' => 'John',
          'poaCode' => '123'
        }
      ]
    }
  end

  context 'VANotify Job' do
    before do
      service_double = instance_double(ClaimsApi::ManageRepresentativeService)
      allow(ClaimsApi::ManageRepresentativeService).to receive(:new).with(any_args)
                                                                    .and_return(service_double)
      allow(service_double).to receive(:read_poa_request_by_ptcpnt_id).with(any_args).and_return(poa_request_response)
    end

    it 'queues when the job when the feature flag is enabled' do
      allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_poa_va_notify).and_return(true)
      expect(ClaimsApi::VANotifyDeclinedJob).to receive(:perform_async)

      subject.call
    end

    it 'does not enqueue the job when the feature flag is disabled' do
      allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_poa_va_notify).and_return(false)
      expect(ClaimsApi::VANotifyDeclinedJob).not_to receive(:perform_async)

      subject.call
    end
  end
end
