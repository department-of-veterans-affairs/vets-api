# frozen_string_literal: true

require 'rails_helper'
require 'bgs/dependents'
require 'bgs/service'
require 'bgs/exceptions'

RSpec.describe BGS::Dependents do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:proc_id) { '3828033' }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674) }

  describe '#create' do
    context 'adding children' do
      let(:adopted_payload) { FactoryBot.build(:adopted_child_lives_with_veteran) }

      it 'returns a hash for biological child that does not live with veteran' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: all_flows_payload,
            user: user_object
          ).create

          expect(dependents).to include(
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

        VCR.use_cassette('bgs/dependents/children/apdopted_child_lives_with_veteran') do
          expect_any_instance_of(BGS::Service).to receive(:create_address)
            .with(a_hash_including(veteran_address_info)).at_most(4).times
            .and_call_original

          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: adopted_payload,
            user: user_object
          ).create

          expect(dependents).to include(
            a_hash_including(
              family_relationship_type_name: 'Adopted Child',
              participant_relationship_type_name: 'Child',
              type: 'child'
            )
          )
        end
      end
    end

    context 'reporting a death' do
      it 'returns a hash with a spouse type death' do
        VCR.use_cassette('bgs/dependents/create/death') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: all_flows_payload,
            user: user_object
          ).create

          expect(dependents).to include(
            a_hash_including(
              family_relationship_type_name: 'Spouse',
              participant_relationship_type_name: 'Spouse',
              type: 'death'
            )
          )
        end
      end
    end

    context 'reporting a divorce' do
      it 'returns an hash with divorce data' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: all_flows_payload,
            user: user_object
          ).create

          # TODO: this expectation will change when we get the new data keys from the FE
          expect(dependents).to include(
            a_hash_including(
              divorce_state: 'FL',
              divorce_city: 'Tampa'
              # marriage_termination_type_code: 'Divorce'
            )
          )
        end
      end
    end

    context 'reporting stepchild no longer part of household' do
      it 'returns an hash that represents a stepchild getting half of their expenses paid' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: all_flows_payload,
            user: user_object
          ).create

          expect(dependents).to include(
            a_hash_including(
              family_relationship_type_name: 'Stepchild',
              participant_relationship_type_name: 'Child',
              living_expenses_paid_amount: '.5'
            )
          )
        end
      end
    end

    context 'report marriage of a child under 18' do
      it 'returns a hash that represents a married child under 18' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: all_flows_payload,
            user: user_object
          ).create

          expect(dependents).to include(
            a_hash_including(
              event_date: '1977-02-01',
              family_relationship_type_name: 'Other',
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
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: all_flows_payload,
            user: user_object
          ).create

          expect(dependents).to include(
            a_hash_including(
              participant_relationship_type_name: 'Child',
              family_relationship_type_name: 'Other',
              event_date: '2019-03-03',
              type: 'not_attending_school'
            )
          )
        end
      end
    end

    context 'report 674' do
      it 'returns a hash that represents child over 18 attending school' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id: proc_id,
            payload: all_flows_payload,
            user: user_object
          ).create

          expect(dependents).to include(
            a_hash_including(
              type: '674',
              participant_relationship_type_name: 'Child',
              family_relationship_type_name: 'Other'
            )
          )
        end
      end
    end
  end
end
