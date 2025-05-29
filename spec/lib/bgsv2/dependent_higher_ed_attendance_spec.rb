# frozen_string_literal: true

require 'rails_helper'
require 'bgsv2/dependent_higher_ed_attendance'

RSpec.describe BGSV2::DependentHigherEdAttendance do
  let(:user_object) { create(:evss_user, :loa3) }
  let(:proc_id) { '3831414' }
  let(:form_674_only) { build(:form_674_only) }
  let(:form_674_only_v2) { build(:form_674_only_v2) }

  context 'with va_dependents_v2 on' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
    end

    describe '#create' do
      context 'reporting a child 18 to 23 years old attending school' do
        it 'returns a hash with a relationship type Child' do
          VCR.use_cassette('bgs/dependent_higher_ed_attendance/create') do
            dependents = BGSV2::DependentHigherEdAttendance.new(
              proc_id:,
              payload: form_674_only_v2,
              user: user_object,
              student: form_674_only_v2['dependents_application']['student_information'][0]
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
end
