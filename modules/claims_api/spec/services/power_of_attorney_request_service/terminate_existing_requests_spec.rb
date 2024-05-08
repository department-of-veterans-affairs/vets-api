# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::TerminateExistingRequests do
  subject { described_class.new(participant_id) }

  let(:participant_id) { '600036513' }

  describe '#call' do
    it 'reads the participant veteran_representatives' do
      file_name = 'claims_api/power_of_attorney_request_service/terminate_existing_requests/with_requests_to_terminate'
      VCR.use_cassette(file_name) do
        expect_any_instance_of(ClaimsApi::VeteranRepresentativeService)
          .to receive(:read_all_veteran_representatives)
          .with(type_code: '21-22', ptcpnt_id: participant_id)
          .and_call_original

        subject.call
      end
    end

    it 'updates the non-obsolete requests' do
      file_name = 'claims_api/power_of_attorney_request_service/terminate_existing_requests/with_requests_to_terminate'
      VCR.use_cassette(file_name) do
        receive_count = 0
        allow_any_instance_of(ClaimsApi::ManageRepresentativeService).to receive(:update_poa_request) {
                                                                           receive_count += 1
                                                                         }

        subject.call

        expect(receive_count).to eq(3)
      end
    end

    it 'does not attempt to update requests' do
      file_name = 'claims_api/power_of_attorney_request_service/terminate_existing_requests/no_requests_to_terminate'
      VCR.use_cassette(file_name) do
        receive_count = 0
        allow_any_instance_of(ClaimsApi::ManageRepresentativeService).to receive(:update_poa_request) {
          receive_count += 1
        }

        subject.call

        expect(receive_count).to eq(0)
      end
    end
  end
end
