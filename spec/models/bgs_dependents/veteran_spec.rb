# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::Veteran do
  let(:person) { { first_nm: 'foo', last_nm: 'bar' } }
  let(:address) { { addrs_one_txt: '123 mainstreet', cntry_nm: 'USA', vnp_ptcpnt_addrs_id: '116343' } }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674) }
  let(:veteran_response_result_sample) do
    {
      vnp_participant_id: '149500',
      type: 'veteran',
      benefit_claim_type_end_product: '134',
      vnp_participant_address_id: '116343',
      file_number: '1234'
    }
  end
  let(:user) do
    {
      participant_id: '600061742',
      ssn: '796043735',
      first_name: 'WESLEY',
      last_name: 'FORD',
      external_key: 'abraham.lincoln@vets.gov',
      icn: '14512449011616630'
    }
  end
  let(:vet) { described_class.new('12345', user) }
  let(:formatted_params_result) do
    {
      'first' => 'WESLEY',
      'last' => 'FORD',
      'phone_number' => '1112223333',
      'email_address' => 'foo@foo.com',
      'country_name' => 'USA',
      'address_line1' => '8200 Doby LN',
      'city' => 'Pasadena',
      'state_code' => 'CA',
      'zip_code' => '21122',
      'vet_ind' => 'Y',
      'martl_status_type_cd' => 'Separated'
    }
  end

  describe '#formatted_params' do
    it 'formats params given a payload' do
      expect(vet.formatted_params(all_flows_payload))
        .to include(formatted_params_result)
    end
  end

  describe '#veteran_response' do
    it 'formats params veteran response' do
      expect(
        vet.veteran_response({ vnp_ptcpnt_id: '149500' }, '1234', address, '134')
      ).to include(veteran_response_result_sample)
    end
  end
end
