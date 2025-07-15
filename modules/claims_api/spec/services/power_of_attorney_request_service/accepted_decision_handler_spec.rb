# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::AcceptedDecisionHandler do
  subject { described_class.new(ptcpnt_id:, proc_id:, poa_code:, metadata:, claimant_ptcpnt_id:) }

  let(:clazz) { described_class }

  context 'Gathering all the required POA data' do
    context 'for a veteran filing' do
      let(:ptcpnt_id) { '600045025' }
      let(:proc_id) { '3864182' }
      let(:poa_code) { '083' }
      let(:claimant_ptcpnt_id) {}
      let(:metadata) do
        { 'veteran' => { 'vnp_phone_id' => '106175', 'vnp_email_id' => '148885', 'vnp_mail_id' => '148886' } }
      end
      let(:expected_veteran_response) do
        {
          service_number: '123678453',
          insurance_numbers: '1234567890',
          phone_number: '5555551234',
          claimant_relationship: 'Spouse',
          poa_code: '083',
          organization_name: 'DISABLED AMERICAN VETERANS',
          representative_first_name: 'John',
          representative_last_name: 'Doe',
          representative_title: nil,
          section_7332_auth: 'true',
          limitation_alcohol: 'true',
          limitation_drug_abuse: 'true',
          limitation_hiv: 'true',
          limitation_sca: 'true',
          change_address_auth: 'true',
          addrs_one_txt: '2719 Hyperion Ave',
          addrs_two_txt: 'Apt 2',
          city_nm: 'Los Angeles',
          cntry_nm: 'USA',
          prvnc_nm: nil,
          zip_prefix_nbr: '92264',
          zip_first_suffix_nbr: '0200',
          email_addrs_txt: nil
        }
      end

      it 'returns expected data' do
        VCR.use_cassette('claims_api/power_of_attorney_request_service/decide/valid_accepted_veteran') do
          res = subject.call

          expect(res).to match(expected_veteran_response)
        end
      end
    end

    context 'for a dependent claimant filing' do
      let(:ptcpnt_id) { '600045025' }
      let(:proc_id) { '3864182' }
      let(:poa_code) { '083' }
      let(:claimant_ptcpnt_id) { '600264235' }
      let(:metadata) do
        {
          'veteran' => { 'vnp_mail_id' => '157252', 'vnp_email_id' => '157251', 'vnp_phone_id' => '111641' },
          'claimant' => { 'vnp_mail_id' => '157253', 'vnp_email_id' => '157254', 'vnp_phone_id' => '111642' }
        }
      end

      let(:expected_dependent_response) do
        {
          service_number: '123678453',
          insurance_numbers: '1234567890',
          phone_number: '5555551234',
          claimant_relationship: 'Spouse',
          poa_code: '083',
          organization_name: 'DISABLED AMERICAN VETERANS',
          representative_first_name: 'John',
          representative_last_name: 'Doe',
          representative_title: nil,
          section_7332_auth: 'true',
          limitation_alcohol: 'true',
          limitation_drug_abuse: 'true',
          limitation_hiv: 'true',
          limitation_sca: 'true',
          change_address_auth: 'true',
          addrs_one_txt: '2719 Hyperion Ave',
          addrs_two_txt: 'Apt 2',
          city_nm: 'Los Angeles',
          cntry_nm: 'USA',
          prvnc_nm: nil,
          zip_prefix_nbr: '92264',
          zip_first_suffix_nbr: '0200',
          email_addrs_txt: nil,
          claimant: {
            addrs_one_txt: '123 Main St',
            addrs_two_txt: 'Apt 3',
            city_nm: 'Boston',
            cntry_nm: 'USA',
            prvnc_nm: nil,
            zip_prefix_nbr: '02110',
            zip_first_suffix_nbr: '1000',
            email_addrs_txt: nil,
            phone_nbr: '5555559876'
          }
        }
      end

      it 'returns expected data' do
        VCR.use_cassette('claims_api/power_of_attorney_request_service/decide/valid_accepted_dependent') do
          res = subject.call

          expect(res).to match(expected_dependent_response)
        end
      end
    end
  end
end
