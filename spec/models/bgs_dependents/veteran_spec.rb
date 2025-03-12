# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::Veteran do
  let(:address) { { addrs_one_txt: '123 mainstreet', cntry_nm: 'USA', vnp_ptcpnt_addrs_id: '116343' } }
  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }
  let(:all_flows_payload_v2) { build(:form686c_674_v2) }
  let(:veteran_response_result_sample) do
    {
      vnp_participant_id: '149500',
      type: 'veteran',
      benefit_claim_type_end_product: '134',
      vnp_participant_address_id: '116343',
      file_number: '1234'
    }
  end
  let(:user) { create(:evss_user, :loa3) }
  let(:vet) { described_class.new('12345', user) }
  let(:formatted_params_result) do
    {
      'first' => 'WESLEY',
      'last' => 'FORD',
      'phone_number' => '1112223333',
      'email_address' => 'foo@foo.com',
      'country_name' => 'USA',
      'address_line1' => '2037400 twenty ninth St',
      'city' => 'Pasadena',
      'state_code' => 'CA',
      'zip_code' => '21122',
      'vet_ind' => 'Y',
      'martl_status_type_cd' => 'Separated'
    }
  end
  let(:formatted_params_result_v2) do
    {
      'first' => 'WESLEY',
      'last' => 'FORD',
      'phone_number' => '5555555555',
      'email_address' => 'test@test.com',
      'country' => 'USA',
      'street' => '123 fake street',
      'street2' => 'test2',
      'street3' => 'test3',
      'city' => 'portland',
      'state' => 'ME',
      'postal_code' => '04102',
      'vet_ind' => 'Y',
      'martl_status_type_cd' => 'Separated'
    }
  end

  context 'with va_dependents_v2 off' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(false)
    end

    describe '#formatted_params' do
      it 'formats params given a veteran that is separated' do
        expect(vet.formatted_params(all_flows_payload)).to include(formatted_params_result)
      end

      it 'formats params given a veteran that is married' do
        formatted_params_result['martl_status_type_cd'] = 'Married'
        all_flows_payload['dependents_application']['does_live_with_spouse']['spouse_does_live_with_veteran'] = true

        expect(vet.formatted_params(all_flows_payload)).to include(formatted_params_result)
      end
    end

    describe '#veteran_response' do
      it 'formats params veteran response' do
        expect(
          vet.veteran_response(
            { vnp_ptcpnt_id: '149500' },
            address,
            { va_file_number: '1234',
              claim_type_end_product: '134',
              location_id: '310',
              net_worth_over_limit_ind: 'Y' }
          )
        ).to include(veteran_response_result_sample)
      end
    end
  end

  context 'with va_dependents_v2 on' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
    end

    describe '#formatted_params' do
      it 'formats params given a veteran that is separated' do
        expect(vet.formatted_params(all_flows_payload_v2)).to include(formatted_params_result_v2)
      end

      it 'formats params given a veteran that is married' do
        formatted_params_result_v2['martl_status_type_cd'] = 'Married'
        all_flows_payload_v2['dependents_application']['does_live_with_spouse']['spouse_does_live_with_veteran'] = true

        expect(vet.formatted_params(all_flows_payload_v2)).to include(formatted_params_result_v2)
      end
    end

    describe '#veteran_response' do
      it 'formats params veteran response' do
        expect(
          vet.veteran_response(
            { vnp_ptcpnt_id: '149500' },
            address,
            { va_file_number: '1234',
              claim_type_end_product: '134',
              location_id: '310',
              net_worth_over_limit_ind: 'Y' }
          )
        ).to include(veteran_response_result_sample)
      end
    end
  end
end
