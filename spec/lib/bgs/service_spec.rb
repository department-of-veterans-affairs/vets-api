# frozen_string_literal: true

require 'rails_helper'
require 'bgs/service'

RSpec.describe BGS::Service do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:bgs_service) { BGS::Service.new(user_object) }
  let(:proc_id) { '3829671' }
  let(:participant_id) { '149456' }

  context 'direct deposit methods' do
    let(:user_object) { build(:ch33_dd_user) }

    context 'with a user that has no icn' do
      before do
        allow(user_object).to receive(:icn).and_return(nil)
        allow(user_object).to receive(:uuid).and_return('b2fab2b5-6af0-45e1-a9e2-394347af91ef')
      end

      it 'retrieves a users dd eft info' do
        VCR.use_cassette('bgs/service/find_ch33_dd_eft_no_icn', VCR::MATCH_EVERYTHING) do
          response = bgs_service.find_ch33_dd_eft
          expect(response.body[:find_ch33_dd_eft_response][:return][:dposit_acnt_nbr]).to eq('444')
        end
      end
    end

    it 'retrieves a users dd eft info' do
      VCR.use_cassette('bgs/service/find_ch33_dd_eft', VCR::MATCH_EVERYTHING) do
        response = bgs_service.find_ch33_dd_eft
        expect(response.body[:find_ch33_dd_eft_response][:return][:dposit_acnt_nbr]).to eq('123')
      end
    end

    it 'updates a users dd eft info' do
      VCR.use_cassette('bgs/service/update_ch33_dd_eft', VCR::MATCH_EVERYTHING) do
        response = bgs_service.update_ch33_dd_eft(
          '122239982',
          '444',
          true
        )
        expect(response.body[:update_ch33_dd_eft_response][:return][:return_message]).to eq('SUCCESS')
      end
    end
  end

  describe '#create_proc' do
    it 'creates a participant and returns a vnp_particpant_id' do
      VCR.use_cassette('bgs/service/create_proc') do
        response = bgs_service.create_proc

        expect(response).to have_key(:vnp_proc_id)
      end
    end
  end

  describe '#create_proc_form' do
    it 'creates a participant and returns a vnp_particpant_id' do
      VCR.use_cassette('bgs/service/create_proc_form') do
        response = bgs_service.create_proc_form('21874')

        expect(response).to have_key(:comp_id)
      end
    end
  end

  describe '#update_proc' do
    it 'creates a participant and returns a vnp_particpant_id' do
      VCR.use_cassette('bgs/service/update_proc') do
        response = bgs_service.update_proc('21874')

        expect(response).to a_hash_including(vnp_proc_state_type_cd: 'Ready')
      end
    end
  end

  describe '#create_participant' do
    it 'creates a participant and returns a vnp_particpant_id' do
      VCR.use_cassette('bgs/service/create_participant') do
        response = bgs_service.create_participant(proc_id)

        expect(response).to have_key(:vnp_ptcpnt_id)
      end
    end

    context 'errors' do
      it 'raises a BGS::ServiceException exception' do
        VCR.use_cassette('bgs/service/errors/create_participant') do
          expect { bgs_service.create_participant('invalid_proc_id') }.to raise_error(BGS::ServiceException)
        end
      end

      it 'retries 3 times' do
        VCR.use_cassette('bgs/service/errors/create_participant') do
          expect(bgs_service).to receive(:notify_of_service_exception).exactly(3).times

          bgs_service.create_participant('invalide_proc_id')
        end
      end
    end
  end

  describe '#create_person' do
    it 'creates a person and returns given data' do
      payload = {
        vnp_proc_id: proc_id,
        vnp_ptcpnt_id: participant_id,
        first_nm: 'vet first name',
        middle_nm: 'vet middle name',
        last_nm: 'vet last name',
        suffix_nm: 'Jr',
        brthdy_dt: '07/04/1969',
        birth_state_cd: 'FL',
        file_nbr: '12345',
        ssn_nbr: '123341234',
        death_dt: '01/01/2020',
        ever_maried_ind: 'Y',
        vet_ind: 'Y'
      }

      VCR.use_cassette('bgs/service/create_person') do
        response = bgs_service.create_person(payload)

        expect(response).to include(last_nm: 'vet last name')
      end
    end
  end

  describe '#create_address' do
    it 'crates an address record and returns given data' do
      payload = {
        address_line1: '123 mainstreet rd.',
        city: 'Tampa',
        state_code: 'FL',
        vnp_ptcpnt_id: participant_id,
        vnp_proc_id: proc_id,
        efctv_dt: Time.current.iso8601,
        ptcpnt_addrs_type_nm: 'Mailing',
        shared_addrs_ind: 'N',
        zip_code: '11234',
        email_address: 'foo@foo.com'
      }

      VCR.use_cassette('bgs/service/create_address') do
        response = bgs_service.create_address(payload)

        expect(response).to include(addrs_one_txt: '123 mainstreet rd.')
      end
    end
  end

  describe '#create_phone' do
    it 'creates a phone record' do
      payload = {
        'phone_number' => '5555555555'
      }

      VCR.use_cassette('bgs/service/create_phone') do
        response = bgs_service.create_phone(proc_id, participant_id, payload)

        expect(response).to have_key(:vnp_ptcpnt_phone_id)
      end
    end
  end

  describe '#get_regional_office_by_zip_code' do
    it 'returns a valid regional office response' do
      VCR.use_cassette('bgs/service/get_regional_office_by_zip_code') do
        response = bgs_service.get_regional_office_by_zip_code('19018', 'USA', '', 'CP', '123')

        expect(response).to eq('310')
      end
    end
  end

  describe '#find_regional_offices' do
    it 'returns a list of regional offices' do
      VCR.use_cassette('bgs/service/find_regional_offices') do
        response = bgs_service.find_regional_offices

        expect(response).to be_an_instance_of(Array)
        # don't want to use an exact match here
        # in case regional offices get closed or added
        expect(response.size).to be > 1
      end
    end
  end
end
