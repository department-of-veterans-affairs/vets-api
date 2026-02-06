# frozen_string_literal: true

require 'rails_helper'
require 'bgs/vnp_veteran'

RSpec.describe BGS::VnpVeteran do
  let(:user_object) { create(:evss_user, :loa3) }
  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }
  let(:all_flows_payload_v2) { build(:form686c_674_v2) }
  let(:formatted_payload) do
    {
      'first' => 'WESLEY',
      'middle' => nil,
      'last' => 'FORD',
      'phone_number' => '1112223333',
      'email_address' => 'foo@foo.com',
      'country_name' => 'USA',
      'address_line1' => '2037400 twenty',
      'address_line2' => 'ninth St apt 2222',
      'address_line3' => 'Bldg 33333',
      'city' => 'Pasadena',
      'state_code' => 'CA',
      'zip_code' => '21122',
      'vet_ind' => 'Y',
      'martl_status_type_cd' => 'Separated',
      'veteran_address' => {
        'country_name' => 'USA',
        'address_line1' => '2037400 twenty',
        'address_line2' => 'ninth St apt 2222',
        'address_line3' => 'Bldg 33333',
        'city' => 'Pasadena',
        'state_code' => 'CA',
        'zip_code' => '21122'
      }
    }
  end
  let(:formatted_payload_v2) do
    {
      'first' => 'WESLEY',
      'middle' => nil,
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
      'martl_status_type_cd' => 'Separated',
      'address_line1' => '123 fake street',
      'address_line2' => 'test2 test3',
      'address_line3' => nil,
      'veteran_address' => {
        'country' => 'USA',
        'street' => '123 fake street',
        'street2' => 'test2',
        'street3' => 'test3',
        'city' => 'portland',
        'state' => 'ME',
        'postal_code' => '04102',
        'address_line1' => '123 fake street',
        'address_line2' => 'test2 test3',
        'address_line3' => nil
      }
    }
  end

  describe '#create' do
    context 'married veteran' do
      it 'returns a VnpPersonAddressPhone object' do
        VCR.use_cassette('bgs/vnp_veteran/create') do
          vnp_veteran = BGS::VnpVeteran.new(
            proc_id: '3828241',
            payload: all_flows_payload_v2,
            user: user_object,
            claim_type: '130DPNEBNADJ'
          ).create

          expect(vnp_veteran).to eq(
            vnp_participant_id: '151031',
            first_name: 'WESLEY',
            last_name: 'FORD',
            vnp_participant_address_id: '117658',
            file_number: '987654321',
            address_line_one: '8200 Doby LN',
            address_line_two: nil,
            address_line_three: nil,
            address_country: 'USA',
            address_state_code: 'CA',
            address_city: 'Pasadena',
            address_zip_code: '21122',
            address_type: nil,
            mlty_postal_type_cd: nil,
            mlty_post_office_type_cd: nil,
            foreign_mail_code: nil,
            type: 'veteran',
            benefit_claim_type_end_product: '139',
            regional_office_number: '313',
            location_id: '343',
            net_worth_over_limit_ind: 'Y'
          )
        end
      end
    end

    context 'default location id' do
      it 'returns 347 when BGS::Service#find_regional_offices returns nil' do
        VCR.use_cassette('bgs/vnp_veteran/create') do
          expect_any_instance_of(BGS::Service).to receive(:find_regional_offices).and_return nil

          vnp_veteran = BGS::VnpVeteran.new(
            proc_id: '3828241',
            payload: all_flows_payload_v2,
            user: user_object,
            claim_type: '130DPNEBNADJ'
          ).create

          expect(vnp_veteran).to include(location_id: '347')
        end
      end

      it 'returns 347 when BGS::Service#get_regional_office_by_zip_code returns an invalid regional office' do
        VCR.use_cassette('bgs/vnp_veteran/create') do
          expect_any_instance_of(BGS::Service)
            .to receive(:get_regional_office_by_zip_code).and_return 'invalid regional office'

          vnp_veteran = BGS::VnpVeteran.new(
            proc_id: '3828241',
            payload: all_flows_payload_v2,
            user: user_object,
            claim_type: '130DPNEBNADJ'
          ).create

          expect(vnp_veteran).to include(location_id: '347')
        end
      end
    end

    it 'calls BGS::Service: #create_person, #create_phone, and #create_address' do
      vet_person_hash = {
        vnp_proc_id: '12345',
        vnp_ptcpnt_id: '151031',
        first_nm: 'WESLEY',
        middle_nm: nil,
        last_nm: 'FORD',
        suffix_nm: nil,
        birth_state_cd: nil,
        birth_city_nm: nil,
        file_nbr: '987654321',
        ssn_nbr: '987654321',
        death_dt: nil,
        ever_maried_ind: nil,
        vet_ind: 'Y',
        martl_status_type_cd: 'Separated'
      }

      expected_address = {
        addrs_one_txt: '123 fake street',
        addrs_two_txt: 'test2 test3',
        addrs_three_txt: nil,
        city_nm: 'portland',
        cntry_nm: 'USA',
        email_addrs_txt: 'test@test.com',
        mlty_post_office_type_cd: nil,
        mlty_postal_type_cd: nil,
        postal_cd: 'ME',
        prvnc_nm: 'ME',
        ptcpnt_addrs_type_nm: 'Mailing',
        shared_addrs_ind: 'N',
        vnp_proc_id: '12345',
        vnp_ptcpnt_id: '151031',
        zip_prefix_nbr: '04102'
      }
      VCR.use_cassette('bgs/vnp_veteran/create') do
        expect_any_instance_of(BGS::Service).to receive(:create_person)
          .with(a_hash_including(vet_person_hash))
          .and_call_original

        expect_any_instance_of(BGS::Service).to receive(:create_phone)
          .with(anything, anything, a_hash_including(formatted_payload_v2))
          .and_call_original

        expect_any_instance_of(BGS::Service).to receive(:create_address)
          .with(a_hash_including(expected_address))
          .and_call_original

        BGS::VnpVeteran.new(
          proc_id: '12345',
          payload: all_flows_payload_v2,
          user: user_object,
          claim_type: '130DPNEBNADJ'
        ).create
      end
    end

    context 'SSN is not 9 digits' do
      before { all_flows_payload_v2['veteran_information']['ssn'] = '12345678' }

      it 'sets ssn to User#ssn' do
        VCR.use_cassette('bgs/vnp_veteran/create') do
          user_object = create(:evss_user, :loa3, ssn: '123456789')
          vnp_veteran = BGS::VnpVeteran.new(
            proc_id: '3828241',
            payload: all_flows_payload_v2,
            user: user_object,
            claim_type: '130DPNEBNADJ'
          )
          expect(Rails.logger).to receive(:info).with('Malformed SSN! Reassigning to User#ssn.',
                                                      include(service: 'bgs'))
          expect(Rails.logger).to receive(:info).with('[BGS::Service] log_and_return called',
                                                      anything).at_least(:once)
          expect_any_instance_of(BGS::Service).to receive(:create_person).with(hash_including(ssn_nbr: '123456789'))
          vnp_veteran.create
        end
      end

      context 'User#ssn returns the same invalid ssn' do
        it 'logs an error' do
          VCR.use_cassette('bgs/vnp_veteran/create') do
            allow_any_instance_of(User).to receive(:ssn).and_return('12345678')
            vnp_veteran = BGS::VnpVeteran.new(
              proc_id: '3828241',
              payload: all_flows_payload_v2,
              user: user_object,
              claim_type: '130DPNEBNADJ'
            )

            expect(Rails.logger).to receive(:info).with('Malformed SSN! Reassigning to User#ssn.',
                                                        include(service: 'bgs'))
            expect(Rails.logger).to receive(:info).with('[BGS::Service] log_and_return called',
                                                        anything).at_least(:once)
            expect_any_instance_of(BGS::Service).to receive(:create_person).with(hash_including(ssn_nbr: '12345678'))
            vnp_veteran.create
          end
        end
      end

      context 'User#ssn returns ********' do
        it 'logs an error to Sentry' do
          VCR.use_cassette('bgs/vnp_veteran/create') do
            allow_any_instance_of(User).to receive(:ssn).and_return('********')
            vnp_veteran = BGS::VnpVeteran.new(
              proc_id: '3828241',
              payload: all_flows_payload_v2,
              user: user_object,
              claim_type: '130DPNEBNADJ'
            )
            expect(Rails.logger).to receive(:info).with('[BGS::Service] log_and_return called',
                                                        anything).at_least(:once)
            expect(Rails.logger).to receive(:info).with('Malformed SSN! Reassigning to User#ssn.',
                                                        include(service: 'bgs'))
            expect(Rails.logger).to receive(:error).with('SSN is redacted!', include(service: 'bgs'))
            expect_any_instance_of(BGS::Service).to receive(:create_person).with(hash_including(ssn_nbr: '********'))
            vnp_veteran.create
          end
        end
      end
    end

    context 'veteran has UK address' do
      it "uses 'United Kingdom' for the country name instead of the full ISO 3166-1 name" do
        # rubocop:disable Layout/LineLength
        all_flows_payload_v2['dependents_application']['veteran_contact_information']['veteran_address']['country'] = 'GBR'
        all_flows_payload_v2['dependents_application']['veteran_contact_information']['veteran_address']['city'] = 'APO'
        all_flows_payload_v2['dependents_application']['veteran_contact_information']['veteran_address']['international_postal_code'] = '67400'
        # rubocop:enable Layout/LineLength

        expected_address = { cntry_nm: 'United Kingdom' }

        VCR.use_cassette('bgs/vnp_veteran/create') do
          expect_any_instance_of(BGS::Service).to receive(:create_address)
            .with(a_hash_including(expected_address))
            .and_call_original
          BGS::VnpVeteran.new(
            proc_id: '12345',
            payload: all_flows_payload_v2,
            user: user_object,
            claim_type: '130DPNEBNADJ'
          ).create
        end
      end
    end

    context "veteran has APO address that isn't in the UK" do
      it 'uses IsoCountryCodes to determine the country name' do
        # rubocop:disable Layout/LineLength
        all_flows_payload_v2['dependents_application']['veteran_contact_information']['veteran_address']['country'] = 'ATA'
        all_flows_payload_v2['dependents_application']['veteran_contact_information']['veteran_address']['city'] = 'APO'
        all_flows_payload_v2['dependents_application']['veteran_contact_information']['veteran_address']['international_postal_code'] = '67400'
        # rubocop:enable Layout/LineLength

        expected_address = { cntry_nm: 'Antarctica' }

        VCR.use_cassette('bgs/vnp_veteran/create') do
          expect_any_instance_of(BGS::Service).to receive(:create_address)
            .with(a_hash_including(expected_address))
            .and_call_original
          BGS::VnpVeteran.new(
            proc_id: '12345',
            payload: all_flows_payload_v2,
            user: user_object,
            claim_type: '130DPNEBNADJ'
          ).create
        end
      end
    end

    context 'veteran has APO address with an AE State' do
      it 'uses IsoCountryCodes to determine the country name' do
        # rubocop:disable Layout/LineLength
        all_flows_payload_v2['dependents_application']['veteran_contact_information']['veteran_address']['country'] = 'USA'
        all_flows_payload_v2['dependents_application']['veteran_contact_information']['veteran_address']['city'] = 'APO'
        all_flows_payload_v2['dependents_application']['veteran_contact_information']['veteran_address']['state'] = 'AE'
        all_flows_payload_v2['dependents_application']['veteran_contact_information']['veteran_address']['international_postal_code'] = '67400'
        # rubocop:enable Layout/LineLength

        expected_address = { frgn_postal_cd: nil,
                             mlty_postal_type_cd: 'AE',
                             mlty_post_office_type_cd: 'APO' }

        VCR.use_cassette('bgs/vnp_veteran/create') do
          expect_any_instance_of(BGS::Service).to receive(:create_address)
            .with(a_hash_including(expected_address))
            .and_call_original
          BGS::VnpVeteran.new(
            proc_id: '12345',
            payload: all_flows_payload_v2,
            user: user_object,
            claim_type: '130DPNEBNADJ'
          ).create
        end
      end
    end

    context 'claim_type_end_product parameter' do
      let(:bgs_service) { BGS::Service.new(user_object) }
      let(:benefit_claims) { double('BenefitClaims') }
      let(:mock_services) { BGS::Services.new(external_uid: '123', external_key: '123') }

      before do
        allow(BGS::Service).to receive(:new).and_return(bgs_service)
        allow(bgs_service).to receive_messages(create_participant: {}, find_benefit_claim_type_increment: {},
                                               create_address: {}, get_regional_office_by_zip_code: {},
                                               find_regional_offices: {}, create_person: {}, create_phone: {})
        allow(BGS::Services).to receive(:new).and_return(mock_services)
        allow(mock_services).to receive(:benefit_claims).and_return(benefit_claims)
        allow(benefit_claims).to receive(:find_claims_details_by_participant_id).and_return(
          { bnft_claim_detail: [
            { status_type_cd: 'PEND', cp_claim_end_prdct_type_cd: '130' },
            { status_type_cd: 'PEND', cp_claim_end_prdct_type_cd: '131' },
            { status_type_cd: 'CAN', cp_claim_end_prdct_type_cd: '134' },
            { status_type_cd: 'CLR', cp_claim_end_prdct_type_cd: '136' }
          ] }
        )
      end

      context 'when claim_type_end_product is provided' do
        it 'uses the provided claim_type_end_product and does not call find_benefit_claim_type_increment' do
          expect_any_instance_of(BGS::Service).not_to receive(:find_benefit_claim_type_increment)

          vnp_veteran = BGS::VnpVeteran.new(
            proc_id: '3828241',
            payload: all_flows_payload_v2,
            user: user_object,
            claim_type: '130DPNEBNADJ',
            claim_type_end_product: '130'
          ).create

          expect(vnp_veteran[:benefit_claim_type_end_product]).to eq('130')
        end
      end

      context 'when claim_type_end_product is not provided' do
        it 'calls find_benefit_claim_type_increment to determine the end product code' do
          expect_any_instance_of(BGS::Service).to receive(:find_benefit_claim_type_increment)
            .with('130DPNEBNADJ')
            .and_return('139')

          vnp_veteran = BGS::VnpVeteran.new(
            proc_id: '3828241',
            payload: all_flows_payload_v2,
            user: user_object,
            claim_type: '130DPNEBNADJ'
          ).create

          expect(vnp_veteran[:benefit_claim_type_end_product]).to eq('139')
        end
      end

      context 'when claim_type_end_product is nil' do
        it 'calls find_benefit_claim_type_increment to determine the end product code' do
          expect_any_instance_of(BGS::Service).to receive(:find_benefit_claim_type_increment)
            .with('130DPNEBNADJ')
            .and_return('139')

          vnp_veteran = BGS::VnpVeteran.new(
            proc_id: '3828241',
            payload: all_flows_payload_v2,
            user: user_object,
            claim_type: '130DPNEBNADJ',
            claim_type_end_product: nil
          ).create

          expect(vnp_veteran[:benefit_claim_type_end_product]).to eq('139')
        end
      end

      context 'when claim_type_end_product is an empty string' do
        it 'calls find_benefit_claim_type_increment to determine the end product code' do
          expect_any_instance_of(BGS::Service).to receive(:find_benefit_claim_type_increment)
            .with('130DPNEBNADJ')
            .and_return('139')

          vnp_veteran = BGS::VnpVeteran.new(
            proc_id: '3828241',
            payload: all_flows_payload_v2,
            user: user_object,
            claim_type: '130DPNEBNADJ',
            claim_type_end_product: ''
          ).create

          expect(vnp_veteran[:benefit_claim_type_end_product]).to eq('139')
        end
      end
    end
  end
end
