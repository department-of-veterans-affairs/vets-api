# frozen_string_literal: true
require 'rails_helper'
require 'bgs/value_objects/vnp_person_address_phone'

RSpec.describe BGS::VnpRelationships do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:proc_id) { '3828033' }
  let(:participant_id) { '146189' }
  let(:veteran_object) do
    ValueObjects::VnpPersonAddressPhone.new(
      vnp_proc_id: proc_id,
      vnp_participant_id: participant_id,
      first_name: 'Veteran first name',
      middle_name: 'Veteran middle name',
      last_name: 'Veteran last name',
      vnp_participant_address_id: '113372',
      participant_relationship_type_name: 'Spouse',
      family_relationship_type_name: 'Spouse',
      suffix_name: 'Jr',
      birth_date: '08/08/1988',
      birth_state_code: 'FL',
      birth_city_name: 'Tampa',
      file_number: '2345678',
      ssn_number: '112347',
      phone_number: '5555555555',
      address_line_one: '123 Mainstreet',
      address_line_two: '',
      address_line_three: '',
      address_state_code: 'FL',
      address_country: 'USA',
      address_city: 'Tampa',
      address_zip_code: '22145',
      email_address: 'foo@foo.com',
      death_date: nil,
      begin_date: nil,
      end_date: nil,
      event_date: nil,
      ever_married_indicator: 'N',
      marriage_state: '',
      marriage_city: 'Tampa',
      divorce_state: nil,
      divorce_city: nil,
      marriage_termination_type_code: nil,
      benefit_claim_type_end_product: '681',
      living_expenses_paid_amount: nil
    )
  end

  describe '#create' do
    context 'adding children' do
      it 'returns a relationship hash with correct :ptcpnt_rlnshp_type_nm and :family_rlnshp_type_nm' do
        VCR.use_cassette('bgs/vnp_relationships/create/child') do
          child = double('child')

          allow(child).to receive_messages(
                            vnp_participant_id: participant_id,
                            participant_relationship_type_name: 'Child',
                            family_relationship_type_name: 'Biological',
                            begin_date: nil,
                            end_date: nil,
                            event_date: nil,
                            marriage_state: nil,
                            marriage_city: nil,
                            divorce_state: nil,
                            divorce_city: nil,
                            marriage_termination_type_code: nil,
                            living_expenses_paid_amount: nil
                          )

          dependent_array = [child]
          dependents = BGS::VnpRelationships.new(proc_id: proc_id, veteran: veteran_object, dependents: dependent_array, user: user).create
          expect(dependents.first).to include(ptcpnt_rlnshp_type_nm: 'Child', family_rlnshp_type_nm: 'Biological')
        end
      end
    end

    context 'reporting a divorce' do
      it 'returns a relationship hash with correct :ptcpnt_rlnshp_type_nm and :family_rlnshp_type_nm' do
        VCR.use_cassette('bgs/vnp_relationships/create/divorce') do
          divorce = double('divorce')
          allow(divorce).to receive_messages(
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
                            )

          dependent_array = [divorce]
          dependents = BGS::VnpRelationships.new(proc_id: proc_id, veteran: veteran_object, dependents: dependent_array, user: user).create

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
          death = double('death')
          # Don't really know how to do this
          allow(death).to receive_messages(
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
                          )

          dependent_array = [death]
          dependents = BGS::VnpRelationships.new(proc_id: proc_id, veteran: veteran_object, dependents: dependent_array, user: user).create
          expect(dependents.first).to include(
                                        ptcpnt_rlnshp_type_nm: 'Spouse',
                                        family_rlnshp_type_nm: 'Spouse',
                                        marage_trmntn_type_cd: 'Death'
                                      )
        end
      end
    end

    context 'adding a spouse' do
      it 'returns a relationship hash with correct :ptcpnt_rlnshp_type_nm and :family_rlnshp_type_nm' do
        VCR.use_cassette('bgs/vnp_relationships/create/spouse') do
          spouse = double('spouse')
          allow(spouse).to receive_messages(
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
                           )

          dependent_array = [spouse]
          dependents = BGS::VnpRelationships.new(proc_id: proc_id, veteran: veteran_object, dependents: dependent_array, user: user).create
          expect(dependents.first).to include(
                                        ptcpnt_rlnshp_type_nm: 'Spouse',
                                        family_rlnshp_type_nm: 'Spouse',
                                        marage_state_cd: 'FL',
                                        marage_city_nm: 'Tampa'
                                      )
        end
      end
    end
  end
end
