# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StdInstitutionFacility, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:street_state).class_name('StdState').optional }
    it { is_expected.to belong_to(:mailing_state).class_name('StdState').optional }
  end

  describe 'scopes' do
    let!(:active_facility) { create(:std_institution_facility, deactivation_date: nil) }
    let!(:inactive_facility) { create(:std_institution_facility, deactivation_date: Time.zone.today) }

    it 'includes only active facilities' do
      expect(StdInstitutionFacility.active).to include(active_facility)
      expect(StdInstitutionFacility.active).not_to include(inactive_facility)
    end
  end

  describe 'state associations' do
    let(:state) { create(:std_state) }
    let!(:facility_with_street_state) { create(:std_institution_facility, street_state: state) }
    let!(:facility_with_mailing_state) { create(:std_institution_facility, mailing_state: state) }

    it 'associates with street state correctly' do
      expect(facility_with_street_state.street_state).to eq(state)
    end

    it 'associates with mailing state correctly' do
      expect(facility_with_mailing_state.mailing_state).to eq(state)
    end
  end
end
