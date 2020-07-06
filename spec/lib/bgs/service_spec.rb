# frozen_string_literal: true
require 'rails_helper'

RSpec.describe BGS::Service do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:bgs_service) { BGS::Service.new(user) }
  let(:proc_id) { '3829360' }
  let(:participant_id) { '148886' }
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
  let(:vet_hash) do
    {
      vnp_participant_id: '146232',
      vnp_participant_address_id: '113372',
      file_number: '796149080',
      ssn_number: '796149080',
      benefit_claim_type_end_product: '135',
      first_name: 'John',
      last_name: 'Doe',
      address_line_one: '123 Mainstreet',
      address_city: 'Jensen Beach',
      address_state_code: 'FL',
      address_zip_code: '33456',
      email_address: 'vet@googlevet.com',
      address_country: 'USA'
    }
  end
  let(:vnp_benefit_claim_hash) do
    {
      vnp_proc_id: '3829532',
      vnp_benefit_claim_id: '425502',
      vnp_benefit_claim_type_code: '130DPNEBNADJ',
      claim_jrsdtn_lctn_id: '347',
      intake_jrsdtn_lctn_id: '347',
      claim_received_date: DateTime.current.iso8601,
      program_type_code: 'COMP',
      participant_claimant_id: '149000',
      status_type_code: 'PEND',
      service_type_code: 'CP',
      participant_mail_address_id: '113372',
      vnp_participant_vet_id: '146232'
    }
  end
  let(:benefit_claim_hash) do
    {
      claim_type_code: '130DPNEBNADJ',
      benefit_claim_id: '600195007',
      program_type_code: 'CPL',
      status_type_code: 'PEND',
      service_type_code: 'CP'
    }
  end

  describe '#create_proc' do
    it 'returns a proc record hash' do
      VCR.use_cassette('bgs/service/create_proc') do
        response = bgs_service.create_proc

        expect(response).to have_key(:vnp_proc_id)
      end
    end
  end

  describe '#create_proc_form' do
    it 'returns a proc_form' do
      VCR.use_cassette('bgs/service/create_proc_form') do
        response = bgs_service.create_proc_form(proc_id)

        expect(response).to have_key(:comp_id)
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

  describe '#create_child_school' do
    it 'creates a child school record' do
      VCR.use_cassette('bgs/service/create_child_school') do
        payload = {
          'last_term_school_information' => {
            'name' => 'Another Amazing School',
            'address' => {
              'country_name' => 'USA',
              'address_line1' => '2037 29th St',
              'city' => 'Rock Island',
              'state_code' => 'AR',
              'zip_code' => '61201'
            },
            'term_begin' => '2016-03-04',
            'date_term_ended' => '2017-04-05', # Done
            'classes_per_week' => 4,
            'hours_per_week' => 40
          },
          'current_term_dates' => {
            'official_school_start_date' => '2019-03-03',
            'expected_student_start_date' => '2019-03-05',
            'expected_graduation_date' => '2023-03-03'
          },
          'program_information' => {
            'student_is_enrolled_full_time' => false,
            'course_of_study' => 'An amazing program',
            'classes_per_week' => 4,
            'hours_per_week' => 37
          },
          'school_information' => {
            'name' => 'My Great School',
            'training_program' => 'Something amazing',
            'address' => {
              'country_name' => 'USA',
              'address_line1' => '2037 29th St',
              'address_line2' => 'another line',
              'address_line3' => 'Yet another line',
              'city' => 'Rock Island',
              'state_code' => 'AR',
              'zip_code' => '61201'
            }
          },
        }

        response = bgs_service.create_child_school(proc_id, participant_id, payload)

        expect(response).to have_key(:vnp_child_school_id)
      end
    end
  end

  describe '#create_child_student' do
    it 'creates a child school record' do
      VCR.use_cassette('bgs/service/create_child_student') do
        payload = {
          "student_networth_information" => {
            "savings" => "3455",
            "securities" => "3234",
            "real_estate" => "5623",
            "other_assets" => "4566",
            "remarks" => "Some remarks about the student's net worth"
          },
          "student_earnings_from_school_year" => {
            "earnings_from_all_employment" => "12000",
            "annual_social_security_payments" => "3453",
            "other_annuities_income" => "30595",
            "all_other_income" => "5596"
          },
          "student_expected_earnings_next_year" => {
            "earnings_from_all_employment" => "12000",
            "annual_social_security_payments" => "3940",
            "other_annuities_income" => "3989",
            "all_other_income" => "984"
          },
          "student_address_marriage_tuition" => {
            "address" => {
              "country_name" => "USA",
              "address_line1" => "1019 Robin Cir",
              "city" => "Arroyo Grande",
              "state_code" => "CA",
              "zip_code" => "93420"
            },
            "was_married" => true,
            "marriage_date" => "2015-03-04",
            "tuition_is_paid_by_gov_agency" => 'Y',
            "agency_name" => "Some Agency",
            "date_payments_began" => "2019-02-03"
          },
          "student_will_earn_income_next_year" => true
        }
        response = bgs_service.create_child_student(proc_id, participant_id, payload)

        expect(response).to include(:vnp_ptcpnt_id, :agency_paying_tuitn_nm, :saving_amt, :next_year_ssa_income_amt)
      end
    end
  end

  describe '#create_benefit_claim' do
    it 'creates a benefit claim and returns a vnp_bnft_claim_id' do
      VCR.use_cassette('bgs/service/create_benefit_claim') do
        response = bgs_service.create_benefit_claim('3829532', vet_hash)

        expect(response).to have_key(:vnp_bnft_claim_id)
      end
    end
  end

  describe '#increment_claim_type' do
    it 'gets the next increment for benefit claim type' do
      VCR.use_cassette('bgs/service/increment_claim_type') do
        response = bgs_service.find_benefit_claim_type_increment

        expect(response).to eq('130')
      end
    end
  end

  describe '#insert_benefit_claim' do
    it 'creates a benefit claim and returns a benefit_claim_record' do
      VCR.use_cassette('bgs/service/insert_benefit_claim') do
        response = bgs_service.insert_benefit_claim(vnp_benefit_claim_hash, vet_hash)

        expect(response).to have_key(:benefit_claim_record)
      end
    end
  end

  describe '#vnp_bnft_claim_update' do
    it 'creates a benefit claim and returns a vnp_bnft_claim_id' do
      VCR.use_cassette('bgs/service/vnp_bnft_claim_update') do
        response = bgs_service.vnp_bnft_claim_update(benefit_claim_hash, vnp_benefit_claim_hash)

        expect(response).to have_key(:vnp_bnft_claim_id)
      end
    end
  end
end
