# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA1919 do
  let(:instance) { build(:va1919) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-1919')

  describe 'form data validation' do
    it 'validates required fields are present' do
      expect(instance).to be_valid
    end

    it 'rejects invalid facility codes' do
      form_data = JSON.parse(instance.form)
      form_data['institutionDetails']['facilityCode'] = '123' # Too short
      instance.form = form_data.to_json
      expect(instance).not_to be_valid
    end

    it 'accepts valid proprietary conflicts structure' do
      form_data = JSON.parse(instance.form)
      conflicts = form_data['proprietaryProfitConflicts']
      expect(conflicts).to be_an(Array)
      expect(conflicts.first['affiliatedIndividuals']).to include('first', 'last', 'title', 'individualAssociationType')
    end

    it 'accepts valid all proprietary conflicts structure' do
      form_data = JSON.parse(instance.form)
      conflicts = form_data['allProprietaryProfitConflicts']
      expect(conflicts).to be_an(Array)
      expect(conflicts.first['certifyingOfficial']).to include('first', 'last', 'title')
      expect(conflicts.first).to include('fileNumber', 'enrollmentPeriod')
    end
  end
end
