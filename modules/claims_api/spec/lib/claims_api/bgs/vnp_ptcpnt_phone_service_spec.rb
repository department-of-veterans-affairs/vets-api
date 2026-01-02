# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_ptcpnt_phone_service'

describe ClaimsApi::VnpPtcpntPhoneService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe 'vnp_ptcpnt_phone_create' do
    let(:options) { {} }

    it 'responds with attributes' do
      options[:vnp_proc_id] = '29798'
      options[:vnp_ptcpnt_id] = '44693'
      options[:phone_nbr] = '2225552252'
      options[:efctv_dt] = '2020-07-16T18:20:17Z'

      VCR.use_cassette('claims_api/bgs/vnp_ptcpnt_phone_service/vnp_ptcpnt_phone_create') do
        response = subject.vnp_ptcpnt_phone_create(options)

        expect(response[:vnp_proc_id]).to eq '29798'
        expect(response[:vnp_ptcpnt_id]).to eq '44693'
        expect(response[:phone_type_nm]).to eq 'Daytime'
        expect(response[:phone_nbr]).to eq '2225552252'
        expect(response[:efctv_dt]).to eq '2020-07-16T18:20:17Z'
        expect(response[:vnp_ptcpnt_phone_id]).to eq '30888'
      end
    end

    it 'responds appropriately with invalid options' do
      options[:vnp_proc_id] = 'not-an-id'
      options[:vnp_ptcpnt_id] = nil
      options[:phone_nbr] = '2225552252'
      options[:efctv_dt] = '2020-07-16T18:20:17Z'

      VCR.use_cassette('claims_api/bgs/vnp_ptcpnt_phone_service/invalid_vnp_ptcpnt_phone_create') do
        expect do
          subject.vnp_ptcpnt_phone_create(options)
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end

    it 'responds appropriately with an international number' do
      options[:vnp_proc_id] = '3874842'
      options[:vnp_ptcpnt_id] = '209001'
      options[:phone_nbr] = ' '
      options[:cntry_nbr] = '11'
      options[:frgn_phone_rfrnc_txt] = '223333 4444'
      options[:efctv_dt] = '2025-12-30T19:54:55Z'

      VCR.use_cassette('claims_api/bgs/vnp_ptcpnt_phone_service/valid_vnp_ptcpnt_phone_create_international_phone') do
        res = subject.vnp_ptcpnt_phone_create(options)

        expect(res[:cntry_nbr]).to eq('11')
        expect(res[:frgn_phone_rfrnc_txt]).to eq('223333 4444')
        expect(res[:phone_nbr]).to eq(' ')
      end
    end
  end

  describe 'vnp_ptcpnt_phone_find_by_primary_key' do
    let(:id) do
      {
        id: '111642'
      }
    end

    it 'responds when sent valid params' do
      VCR.use_cassette('claims_api/bgs/vnp_ptcpnt_phone_service/valid_vnp_ptcpnt_phone_find_by_primary_key') do
        response = subject.vnp_ptcpnt_phone_find_by_primary_key(id:)

        expect(response).to include(
          {
            phone_nbr: '5555559876'
          }
        )
      end
    end
  end
end
