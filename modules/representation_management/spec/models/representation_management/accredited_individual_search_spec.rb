# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AccreditedIndividualSearch, type: :model do
  describe 'validations' do
    subject { described_class.new }

    it { expect(subject).to validate_inclusion_of(:distance).in_array(described_class::PERMITTED_MAX_DISTANCES) }
    it { expect(subject).to validate_presence_of(:lat) }
    it { expect(subject).to validate_numericality_of(:lat).is_greater_than_or_equal_to(-90) }
    it { expect(subject).to validate_numericality_of(:lat).is_less_than_or_equal_to(90) }
    it { expect(subject).to validate_presence_of(:long) }
    it { expect(subject).to validate_numericality_of(:long).is_greater_than_or_equal_to(-180) }
    it { expect(subject).to validate_numericality_of(:long).is_less_than_or_equal_to(180) }
    it { expect(subject).to validate_numericality_of(:page).only_integer }
    it { expect(subject).to validate_numericality_of(:per_page).only_integer }
    it { expect(subject).to validate_inclusion_of(:sort).in_array(described_class::PERMITTED_SORTS) }
    it { expect(subject).to validate_presence_of(:type) }
    it { expect(subject).to validate_inclusion_of(:type).in_array(described_class::PERMITTED_TYPES) }
  end
end
