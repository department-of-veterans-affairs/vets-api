# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StdState, type: :model do
  describe 'validations' do
    subject { create(:std_state) }

    it { is_expected.to validate_presence_of(:id) }
    it { is_expected.to validate_uniqueness_of(:id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:postal_name) }
    it { is_expected.to validate_presence_of(:fips_code) }
    it { is_expected.to validate_presence_of(:country_id) }
    it { is_expected.to validate_presence_of(:version) }
    it { is_expected.to validate_presence_of(:created) }
  end

  describe 'associations' do
    it {
      expect(subject).to have_many(:institution_facilities_street)
        .class_name('StdInstitutionFacility')
        .with_foreign_key('street_state_id')
    }

    it {
      expect(subject).to have_many(:institution_facilities_mailing)
        .class_name('StdInstitutionFacility')
        .with_foreign_key('mailing_state_id')
    }
  end

  describe 'relationships with StdInstitutionFacility' do
    let(:state) { create(:std_state) }
    let!(:street_facility) { create(:std_institution_facility, street_state_id: state.id) }
    let!(:mailing_facility) { create(:std_institution_facility, mailing_state_id: state.id) }

    it 'retrieves the correct street facilities' do
      expect(state.institution_facilities_street).to include(street_facility)
      expect(state.institution_facilities_street).not_to include(mailing_facility)
    end

    it 'retrieves the correct mailing facilities' do
      expect(state.institution_facilities_mailing).to include(mailing_facility)
      expect(state.institution_facilities_mailing).not_to include(street_facility)
    end
  end
end
