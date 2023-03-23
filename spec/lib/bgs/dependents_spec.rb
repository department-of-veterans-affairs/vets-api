# frozen_string_literal: true

require 'rails_helper'
require 'bgs/dependents'

RSpec.describe BGS::Dependents do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:proc_id) { '3828033' }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674_kitchen_sink) }

  describe '#create' do
    context 'reporting a death' do
      it 'returns a hash with a spouse type death' do
        VCR.use_cassette('bgs/dependents/create/death') do
          dependents = BGS::Dependents.new(
            proc_id:,
            payload: all_flows_payload,
            user: user_object
          ).create_all

          expect(dependents).to include(
            a_hash_including(
              family_relationship_type_name: 'Spouse',
              participant_relationship_type_name: 'Spouse',
              type: 'death',
              end_date: '2020-01-01T12:00:00+00:00'
            )
          )
        end
      end
    end

    context 'reporting a divorce' do
      it 'returns an hash with divorce data' do
        VCR.use_cassette('bgs/dependents/create') do
          dependents = BGS::Dependents.new(
            proc_id:,
            payload: all_flows_payload,
            user: user_object
          ).create_all

          # TODO: this expectation will change when we get the new data keys from the FE
          expect(dependents).to include(
            a_hash_including(
              divorce_state: 'FL',
              divorce_city: 'Tampa',
              end_date: DateTime.parse('2020-01-01 12:00:00').to_time.iso8601,
              type: 'divorce'
            )
          )
        end
      end
    end
  end
end
