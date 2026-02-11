# frozen_string_literal: true

require 'rails_helper'
require 'bgs/marriages'

RSpec.describe BGS::Marriages do
  let(:user_object) { create(:evss_user, :loa3) }
  let(:proc_id) { '3828033' }
  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }
  let(:all_flows_payload_v2) { build(:form686c_674_v2) }
  let(:spouse_payload_v2) { build(:spouse_v2) }

  describe '#create' do
    context 'adding a spouse' do
      it 'returns hash for spouse who lives with veteran' do
        VCR.use_cassette('bgs/dependents/create/spouse/lives_with_veteran') do
          dependents = BGS::Marriages.new(
            proc_id:,
            payload: spouse_payload_v2,
            user: user_object
          ).create_all

          expect(dependents).to include(
            a_hash_including(
              family_relationship_type_name: 'Spouse',
              participant_relationship_type_name: 'Spouse',
              marriage_city: 'Slawson',
              marriage_state: 'CA',
              type: 'spouse',
              begin_date: '2014-03-04'
            )
          )
        end
      end

      it 'returns hash for spouse who has different address (separated)' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Marriages.new(
            proc_id:,
            payload: all_flows_payload_v2,
            user: user_object
          ).create_all

          expect(dependents).to include(
            a_hash_including(
              family_relationship_type_name: 'Estranged Spouse',
              participant_relationship_type_name: 'Spouse',
              marriage_city: 'portland',
              marriage_state: 'ME',
              type: 'spouse',
              begin_date: '2025-01-01'
            )
          )
        end
      end

      it 'marks spouse as veteran' do
        spouse_vet_hash = {
          birth_city_nm: nil,
          birth_state_cd: nil,
          death_dt: nil,
          ever_maried_ind: 'Y',
          file_nbr: '00000000',
          first_nm: 'Jenny',
          last_nm: 'McCarthy',
          martl_status_type_cd: 'Married',
          middle_nm: 'Lauren',
          ssn_nbr: '323454323',
          suffix_nm: 'Sr.',
          vet_ind: 'Y',
          vnp_proc_id: '3828033',
          vnp_ptcpnt_id: '149487'
        }

        VCR.use_cassette('bgs/dependents/create/spouse/is_veteran') do
          expect_any_instance_of(BGS::Service).to receive(:create_person)
            .with(a_hash_including(spouse_vet_hash))
            .and_call_original

          BGS::Marriages.new(
            proc_id:,
            payload: spouse_payload_v2,
            user: user_object
          ).create_all
        end
      end
    end
  end
end
