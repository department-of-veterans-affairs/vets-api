# frozen_string_literal: true

require 'rails_helper'
require 'bgs/children'

RSpec.describe BGS::Children do
  let(:user_object) { create(:evss_user, :loa3) }
  let(:proc_id) { '3828033' }
  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }
  let(:all_flows_payload_v2) { build(:form686c_674_v2) }

  context 'adding children' do
    let(:adopted_payload) { build(:adopted_child_lives_with_veteran_v2) }
    let(:add_step_child_payload) { build(:step_child_lives_with_veteran_v2) }

    it 'returns a hash for biological child that does not live with veteran' do
      VCR.use_cassette('bgs/dependents/create') do
        children = BGS::Children.new(
          proc_id:,
          payload: all_flows_payload_v2,
          user: user_object
        ).create_all

        expect(children[:dependents]).to include(
          a_hash_including(
            family_relationship_type_name: 'Biological',
            participant_relationship_type_name: 'Child',
            type: 'child'
          )
        )
      end
    end

    it 'returns a hash for adopted child that does live with veteran' do
      veteran_address_info = {
        addrs_one_txt: '8200 Doby LN',
        addrs_three_txt: nil,
        addrs_two_txt: nil,
        city_nm: 'Pasadena',
        cntry_nm: 'USA',
        email_addrs_txt: nil,
        mlty_post_office_type_cd: nil,
        mlty_postal_type_cd: nil,
        postal_cd: 'CA',
        prvnc_nm: 'CA',
        ptcpnt_addrs_type_nm: 'Mailing',
        shared_addrs_ind: 'N',
        vnp_proc_id: '3828033',
        vnp_ptcpnt_id: '149600',
        zip_prefix_nbr: '21122'
      }

      VCR.use_cassette('bgs/children/apdopted_child_lives_with_veteran') do
        expect_any_instance_of(BGS::Service).to receive(:create_address)
          .with(a_hash_including(veteran_address_info)).at_most(4).times
          .and_call_original

        children = BGS::Children.new(
          proc_id:,
          payload: adopted_payload,
          user: user_object
        ).create_all

        expect(children[:dependents]).to include(
          a_hash_including(
            family_relationship_type_name: 'Adopted Child',
            participant_relationship_type_name: 'Child',
            type: 'child'
          )
        )
      end
    end

    it 'returns a hash for step child and spouse/parent of step child' do
      VCR.use_cassette('bgs/dependents/create') do
        children = BGS::Children.new(
          proc_id:,
          payload: add_step_child_payload,
          user: user_object
        ).create_all

        expect(children[:dependents]).to include(
          a_hash_including(
            family_relationship_type_name: 'Stepchild',
            participant_relationship_type_name: 'Child',
            type: 'child'
          )
        )

        expect(children[:step_children]).to include(
          a_hash_including(
            family_relationship_type_name: 'Spouse',
            participant_relationship_type_name: 'Spouse',
            event_date: '2021-09-02',
            begin_date: '2021-09-02',
            type: 'stepchild_parent',
            ssn_nbr: '987654321'
          )
        )
      end
    end
  end

  context 'reporting stepchild no longer part of household' do
    it 'returns an hash that represents a stepchild getting half of their expenses paid' do
      VCR.use_cassette('bgs/children/create_all') do
        children = BGS::Children.new(
          proc_id:,
          payload: all_flows_payload_v2,
          user: user_object
        ).create_all

        expect(children[:step_children]).to include(
          a_hash_including(
            family_relationship_type_name: 'Other',
            participant_relationship_type_name: 'Guardian',
            living_expenses_paid_amount: '.5'
          )
        )
      end
    end
  end

  context 'report marriage of a child under 18' do
    it 'returns a hash that represents a married child under 18' do
      VCR.use_cassette('bgs/dependents/create') do
        children = BGS::Children.new(
          proc_id:,
          payload: all_flows_payload_v2,
          user: user_object
        ).create_all

        expect(children[:dependents]).to include(
          a_hash_including(
            event_date: '2025-01-01',
            family_relationship_type_name: 'Biological',
            participant_relationship_type_name: 'Child',
            type: 'child_marriage'
          )
        )
      end
    end
  end

  context 'report child 18 or older has stopped attending school' do
    it 'returns an hash that represents a married child under 18' do
      VCR.use_cassette('bgs/dependents/create') do
        children = BGS::Children.new(
          proc_id:,
          payload: all_flows_payload_v2,
          user: user_object
        ).create_all

        expect(children[:dependents]).to include(
          a_hash_including(
            participant_relationship_type_name: 'Child',
            family_relationship_type_name: 'Biological',
            event_date: '2024-08-03',
            type: 'not_attending_school'
          )
        )
      end
    end
  end
end
