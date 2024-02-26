# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/profile/v3/bio_path_builder'

describe VAProfile::Profile::V3::BioPathBuilder do
  context 'when bio path is valid' do
    it 'exists? returns true' do
      builder = VAProfile::Profile::V3::BioPathBuilder.new
      expect(builder.bio_path_exists?(:military_occupations)).to be(true)
    end

    it 'adds a bio path to the list of params' do
      builder = VAProfile::Profile::V3::BioPathBuilder.new(:military_admin_decisions)

      expected_params = { bios: [{ bioPath: 'militaryPerson.adminDecisions' }] }
      expect(builder.params).to eq(expected_params)
    end

    it 'adds multiple bio paths to the list of params' do
      builder = VAProfile::Profile::V3::BioPathBuilder.new(:military_occupations,
                                                           :military_admin_decisions,
                                                           :military_transfer_of_eligibility)

      expected_params = {
        bios: [
          { bioPath: 'militaryPerson.militaryOccupations' },
          { bioPath: 'militaryPerson.adminDecisions' },
          { bioPath: 'militaryPerson.transferOfEligibility' }
        ]
      }

      expect(builder.params).to eq(expected_params)
    end
  end

  context 'when bio path is invalid' do
    it 'throws an ArgumentError exception' do
      expect do
        VAProfile::Profile::V3::BioPathBuilder.new(:bad_bio_path)
      end.to raise_error(ArgumentError, 'Invalid bio path: bad_bio_path')
    end
  end
end
