# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::Service do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:user_hash) do
    {
      participant_id: user_object.participant_id,
      ssn: user_object.ssn,
      first_name: user_object.first_name,
      last_name: user_object.last_name,
      external_key: user_object.common_name || user_object.email,
      icn: user_object.icn
    }
  end
  let(:bgs_service) { BGS::Service.new(user_hash) }
  let(:proc_id) { '3829671' }
  let(:participant_id) { '149456' }
  let(:dependent_hash) do
    {
      vnp_participant_id: participant_id,
      participant_relationship_type_name: 'Spouse',
      family_relationship_type_name: 'Spouse',
      begin_date: nil,
      end_date: nil,
      event_date: nil,
      marriage_state: '',
      marriage_city: 'Tampa',
      divorce_state: nil,
      divorce_city: nil,
      marriage_termination_type_code: nil,
      living_expenses_paid_amount: nil
    }
  end

  describe '#create_proc' do
    it 'returns a proc record hash' do
      VCR.use_cassette('bgs/service/create_proc') do
        response = bgs_service.create_proc

        expect(response).to have_key(:vnp_proc_id)
      end
    end

    describe '#create_proc_form' do
      it 'returns a proc_form' do
        VCR.use_cassette('bgs/service/create_proc_form') do
          response = bgs_service.create_proc_form(proc_id)

          expect(response).to have_key(:comp_id)
        end
      end

      context 'errors' do
        it 'raises a BGS::ServiceException exception' do
          VCR.use_cassette('bgs/service/errors/create_proc_form') do
            expect { bgs_service.create_proc_form('invalid_proc_id') }.to raise_error(BGS::ServiceException)
          end
        end

        it 'retries 3 times' do
          VCR.use_cassette('bgs/service/errors/create_proc_form') do
            expect(bgs_service).to receive(:notify_of_service_exception).exactly(3).times

            bgs_service.create_proc_form('invalide_proc_id')
          end
        end
      end
    end
  end

  describe '#update_proc' do
    it 'updates a proc given a proc_id' do
      VCR.use_cassette('bgs/service/update_proc') do
        response = bgs_service.update_proc(proc_id)

        expect(response).to include(vnp_proc_id: proc_id)
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
  end

  describe '#create_person' do
    it 'creates a person and returns given data' do
      payload = {
        'first' => 'vet first name',
        'middle' => 'vet middle name',
        'last' => 'vet last name',
        'suffix' => 'Jr',
        'birth_date' => '07/04/1969',
        'place_of_birth_state' => 'FL',
        'va_file_number' => '12345',
        'ssn' => '123341234',
        'death_date' => '01/01/2020',
        'ever_maried_ind' => 'Y',
        'vet_ind' => 'Y'
      }

      VCR.use_cassette('bgs/service/create_person') do
        response = bgs_service.create_person(proc_id, participant_id, payload)

        expect(response).to include(last_nm: 'vet last name')
      end
    end
  end

  describe '#get_va_file_number' do
    it 'gets the veteran VA File number given their participant id' do
      VCR.use_cassette('bgs/service/get_va_file_number') do
        response = bgs_service.get_va_file_number

        expect(response).to include('796')
      end
    end
  end

  describe '#create_address' do
    it 'crates an address record and returns given data' do
      payload = {
        'address_line1' => '123 mainstreet rd.',
        'city' => 'Tampa',
        'state_code' => 'FL',
        'zip_code' => '11234',
        'email_address' => 'foo@foo.com'
      }

      VCR.use_cassette('bgs/service/create_address') do
        response = bgs_service.create_address(proc_id, participant_id, payload)

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

  describe '#create_relationship' do
    it 'creates a relationship and returns a vnp_relationship_id' do
      VCR.use_cassette('bgs/service/create_relationship') do
        response = bgs_service.create_relationship(proc_id, participant_id, dependent_hash)

        expect(response).to have_key(:vnp_ptcpnt_rlnshp_id)
      end
    end
  end

  describe '#increment_claim_type' do
    it 'gets the next increment for benefit claim type' do
      VCR.use_cassette('bgs/service/increment_claim_type') do
        response = bgs_service.find_benefit_claim_type_increment

        expect(response).to eq('134')
      end
    end
  end
end
