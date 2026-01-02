# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/manage_representative_service'

describe ClaimsApi::PowerOfAttorneyRequestService::Index do
  subject { described_class.new(poa_codes: ['002'], page_size: 10, page_index: 1, filter: {}) }

  describe '#get_poa_list' do
    let(:proc_ids) { %w[10906 10907] }

    let(:metadata_with_claimant) do
      { 'veteran' => { 'vnp_mail_id' => '158364', 'vnp_email_id' => '158365', 'vnp_phone_id' => '112568' },
        'claimant' => { 'vnp_mail_id' => '158366', 'vnp_email_id' => '158367', 'vnp_phone_id' => '112569' } }
    end

    let(:metadata_without_claimant) do
      { 'veteran' => { 'vnp_mail_id' => '158364', 'vnp_email_id' => '158365', 'vnp_phone_id' => '112568' } }
    end

    let(:obj_response_data) do
      {
        'poaRequestRespondReturnVOList' => {
          'poaCode' => '002',
          'procID' => proc_ids[0]
        }
      }
    end

    let(:arr_response_data) do
      {
        'poaRequestRespondReturnVOList' => [{
          'poaCode' => '002',
          'procID' => proc_ids[0]
        }, {
          'poaCode' => '002',
          'procID' => proc_ids[1]
        }]
      }
    end

    let(:service_double) { instance_double(ClaimsApi::ManageRepresentativeService) }

    before do
      allow(ClaimsApi::ManageRepresentativeService).to receive(:new).with(any_args)
                                                                    .and_return(service_double)
    end

    context 'when page size is set to 1' do
      before do
        subject.instance_variable_set(:@page_size, 1)
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
        subject.instance_variable_set(:@page_size, 5)
        allow(service_double).to receive(:read_poa_request).with(any_args).and_return(arr_response_data)
      end

      it 'still works as expected when page_size is > 1' do
        expect do
          subject.get_poa_list
        end.not_to raise_error
      end
    end

    context 'when claimant information is present on the request' do
      before do
        create(:claims_api_power_of_attorney_request,
               proc_id: proc_ids[0], veteran_icn: '1012667169V030190', claimant_icn: '1013093331V548481',
               poa_code: '002', metadata: metadata_with_claimant, power_of_attorney_id: nil)
        create(:claims_api_power_of_attorney_request,
               proc_id: proc_ids[1], veteran_icn: '1012667169V030190', claimant_icn: nil,
               poa_code: '003', metadata: metadata_without_claimant, power_of_attorney_id: nil)
      end

      let(:poa_requests_by_proc_id) do
        { proc_ids[0] => { id: '8602049e-06c1-4c47-b419-4d64fbaed28d', claimant_icn: '1013093331V548481' } }
      end

      describe '#map_list_data' do
        it 'adds claimant ICN to the returned object when it is present on the request' do
          allow(service_double).to receive(:read_poa_request).with(anything).and_return(arr_response_data)

          res = subject.send(:map_list_data, poa_requests_by_proc_id)
          record_with_claimant = res.detect { |record| record['procID'] == proc_ids[0] }

          expect(record_with_claimant['claimant_icn']).to eq('1013093331V548481')
        end
      end
    end
  end
end
