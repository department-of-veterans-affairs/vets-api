# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::VeteranFileNumberLookupService do
  let(:target_veteran) do
    OpenStruct.new(
      icn: '1012832025V743496',
      first_name: 'Wesley',
      last_name: 'Ford',
      middle_name: 'John',
      birth_date: '19630211',
      loa: { current: 3, highest: 3 },
      edipi: nil,
      ssn: '796043735',
      participant_id: '600061742',
      mpi: OpenStruct.new(
        icn: '1012832025V743496',
        profile: OpenStruct.new(ssn: '796043735')
      )
    )
  end

  let(:service) { described_class.new(target_veteran.ssn, target_veteran.participant_id) }

  describe '#check_file_number_exists!' do
    context 'when PersonWebService', vcr: 'claims_api/services/veteran_file_number_lookup_service/bgs_find_by_ssn' do
      it 'returns file number' do
        result = service.check_file_number_exists!

        expect(result).to eq('796043735')
      end
    end

    context 'handling errors' do
      let(:person_web_service) { instance_double(ClaimsApi::PersonWebService) }
      let(:share_error) { BGS::ShareError.new('Some error message') }

      before do
        allow(ClaimsApi::PersonWebService).to receive(:new).with(external_uid: anything,
                                                                 external_key: anything)
                                                           .and_return(person_web_service)
      end

      it 'returns UnprocessableEntity if response is nil' do
        allow(person_web_service).to receive(:find_by_ssn).and_return(nil)

        expect { service.check_file_number_exists! }.to raise_error(
          Common::Exceptions::UnprocessableEntity
        ) do |error|
          expect(error.errors.first[:detail]).to include(
            ClaimsApi::VeteranFileNumberLookupService::UNABLE_TO_LOCATE_ERROR_MESSAGE
          )
        end
      end

      it 'raises FailedDependency and logs the error when BGS::ShareError occurs' do
        allow(person_web_service).to receive(:find_by_ssn).and_raise(share_error)

        expect(ClaimsApi::Logger).to receive(:log).with(
          'poa_find_by_ssn',
          message: ClaimsApi::VeteranFileNumberLookupService::BGS_ERROR_MESSAGE
        )

        expect { service.check_file_number_exists! }.to raise_error(Common::Exceptions::FailedDependency)
      end
    end
  end
end
