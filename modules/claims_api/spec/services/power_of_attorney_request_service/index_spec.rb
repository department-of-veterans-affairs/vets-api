# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/manage_representative_service'

describe ClaimsApi::PowerOfAttorneyRequestService::Index do
  subject { described_class.new(poa_codes: ['002'], page_size: 10, page_index: 1, filter: {}) }

  describe '#get_poa_list' do
    let(:obj_response_data) do
      {
        'poaRequestRespondReturnVOList' => {
          'poaCode' => '002',
          'procID' => '10906'
        }
      }
    end

    let(:arr_response_data) do
      {
        'poaRequestRespondReturnVOList' => [{
          'poaCode' => '002',
          'procID' => '10906'
        }, {
          'poaCode' => '002',
          'procID' => '10907'
        }]
      }
    end

    context 'when page size is set to 1' do
      before do
        @page_size = 1
        service_double = instance_double(ClaimsApi::ManageRepresentativeService)
        allow(ClaimsApi::ManageRepresentativeService).to receive(:new).with(any_args)
                                                                      .and_return(service_double)
        allow(service_double).to receive(:read_poa_request).with(any_args).and_return(obj_response_data)
      end

      it 'does not return an error when page_size is 1' do
        expect do
          subject.get_poa_list
        end.not_to raise_error
      end
    end

    context 'when page size is over 1 and less then the max allowed' do
      before do
        @page_size = 5
        service_double = instance_double(ClaimsApi::ManageRepresentativeService)
        allow(ClaimsApi::ManageRepresentativeService).to receive(:new).with(any_args)
                                                                      .and_return(service_double)
        allow(service_double).to receive(:read_poa_request).with(any_args).and_return(arr_response_data)
      end

      it 'still works as expected when page_size is > 1' do
        expect do
          subject.get_poa_list
        end.not_to raise_error
      end
    end
  end
end
