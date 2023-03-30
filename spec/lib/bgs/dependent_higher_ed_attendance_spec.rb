# frozen_string_literal: true

require 'rails_helper'
require 'bgs/dependent_higher_ed_attendance'

RSpec.describe BGS::DependentHigherEdAttendance do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:proc_id) { '3831414' }
  let(:form_674_only) { FactoryBot.build(:form_674_only) }

  describe '#create' do
    context 'reporting a child 18 to 23 years old attending school' do
      it 'returns a hash with a relationship type Child' do
        VCR.use_cassette('bgs/dependent_higher_ed_attendance/create') do
          dependents = BGS::DependentHigherEdAttendance.new(
            proc_id:,
            payload: form_674_only,
            user: user_object
          ).create

          expect(dependents).to include(
            {
              vnp_participant_id: '151598',
              participant_relationship_type_name: 'Child',
              family_relationship_type_name: 'Biological',
              type: '674'
            }
          )
        end
      end
    end
  end
end
