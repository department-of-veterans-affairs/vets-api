# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::VnpRelationships do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:proc_id) { '3828033' }
  let(:participant_id) { '146189' }
  let(:veteran_hash) { { vnp_participant_id: '146189' } }

  describe '#create_all' do
    context 'adding children' do
      it 'returns a relationship hash with correct :ptcpnt_rlnshp_type_nm and :family_rlnshp_type_nm' do
        VCR.use_cassette('bgs/vnp_relationships/create/child') do
          child = {
            vnp_participant_id: '148953',
            participant_relationship_type_name: 'Child',
            family_relationship_type_name: 'Biological',
            begin_date: nil,
            end_date: nil,
            event_date: nil,
            marriage_state: nil,
            marriage_city: nil,
            divorce_state: nil,
            divorce_city: nil,
            marriage_termination_type_code: 'Death',
            living_expenses_paid_amount: nil,
            type: 'child'
          }

          dependent_array = [child]

          dependents = BGS::VnpRelationships.new(
            proc_id: proc_id, veteran: veteran_hash, dependents: dependent_array, user: user_object
          ).create_all

          expect(dependents.first).to include(
            participant_relationship_type_name: 'Child',
            family_relationship_type_name: 'Biological'
          )
        end
      end
    end

    xcontext 'reporting a divorce' do
      it 'returns a relationship hash with correct :ptcpnt_rlnshp_type_nm and :family_rlnshp_type_nm' do
        VCR.use_cassette('bgs/vnp_relationships/create/divorce') do
          divorce = {
            vnp_participant_id: participant_id,
            participant_relationship_type_name: 'Spouse',
            family_relationship_type_name: 'Ex-Spouse',
            begin_date: nil,
            end_date: nil,
            event_date: '2001-02-03',
            marriage_state: nil,
            marriage_city: nil,
            divorce_state: 'FL',
            divorce_city: 'Tampa',
            marriage_termination_type_code: 'Divorce',
            living_expenses_paid_amount: nil
          }

          dependent_array = [divorce]
          dependents = BGS::VnpRelationships.new(
            proc_id: proc_id, veteran: veteran_hash, dependents: dependent_array, user: user
          ).create_all

          expect(dependents.first).to include(
            ptcpnt_rlnshp_type_nm: 'Spouse',
            family_rlnshp_type_nm: 'Ex-Spouse',
            marage_trmntn_type_cd: 'Divorce',
            marage_trmntn_city_nm: 'Tampa',
            marage_trmntn_state_cd: 'FL'
          )
        end
      end
    end

    context 'reporting a death' do
      it 'returns a relationship hash with correct :ptcpnt_rlnshp_type_nm and :family_rlnshp_type_nm' do
        VCR.use_cassette('bgs/vnp_relationships/create/death') do
          death = {
            vnp_participant_id: participant_id,
            participant_relationship_type_name: 'Spouse',
            family_relationship_type_name: 'Spouse',
            begin_date: nil,
            end_date: nil,
            event_date: '2001-02-03',
            marriage_state: nil,
            marriage_city: nil,
            divorce_state: nil,
            divorce_city: nil,
            marriage_termination_type_code: 'Death',
            living_expenses_paid_amount: nil
          }

          dependent_array = [death]
          dependents = BGS::VnpRelationships.new(
            proc_id: proc_id,
            veteran: veteran_hash,
            dependents: dependent_array,
            user: user_object
          ).create_all
          expect(dependents.first).to include(
            participant_relationship_type_name: 'Spouse',
            family_relationship_type_name: 'Spouse',
            marriage_termination_type_code: 'Death'
          )
        end
      end
    end

    context 'adding a spouse for a veteran' do
      it 'returns a relationship hash with correct :ptcpnt_rlnshp_type_nm and :family_rlnshp_type_nm' do
        VCR.use_cassette('bgs/vnp_relationships/create/spouse') do
          spouse = {
            vnp_participant_id: participant_id,
            participant_relationship_type_name: 'Spouse',
            family_relationship_type_name: 'Spouse',
            begin_date: nil,
            end_date: nil,
            event_date: nil,
            marriage_state: 'FL',
            marriage_city: 'Tampa',
            divorce_state: nil,
            divorce_city: nil,
            marriage_termination_type_code: nil,
            living_expenses_paid_amount: nil
          }

          dependent_array = [spouse]
          dependents = BGS::VnpRelationships.new(
            proc_id: proc_id,
            veteran: veteran_hash,
            dependents: dependent_array,
            user: user_object
          ).create_all
          expect(dependents.first).to include(
            participant_relationship_type_name: 'Spouse',
            family_relationship_type_name: 'Spouse',
            marriage_state: 'FL',
            marriage_city: 'Tampa'
          )
        end
      end
    end

    context 'adding marriage history for a veteran' do
      it 'creates a relationship between a veteran and their former spouses' do
        VCR.use_cassette('bgs/vnp_relationships/create/marriage_history') do
          spouse = {
            vnp_participant_id: participant_id,
            participant_relationship_type_name: 'Spouse',
            family_relationship_type_name: 'Spouse',
            begin_date: nil,
            end_date: nil,
            event_date: nil,
            marriage_state: 'FL',
            marriage_city: 'Tampa',
            divorce_state: nil,
            divorce_city: nil,
            marriage_termination_type_code: nil,
            living_expenses_paid_amount: nil
          }

          dependent_array = [spouse]
          dependents = BGS::VnpRelationships.new(proc_id: proc_id,
                                                 veteran: veteran_hash,
                                                 dependents: dependent_array,
                                                 user: user_object).create_all
          expect(dependents.first).to include(
            participant_relationship_type_name: 'Spouse',
            family_relationship_type_name: 'Spouse',
            marriage_state: 'FL',
            marriage_city: 'Tampa'
          )
        end
      end
    end
  end
end
