# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accreditation, type: :model do
  describe 'validations' do
    subject { build(:accreditation) }

    it { is_expected.to belong_to(:accredited_individual) }
    it { is_expected.to belong_to(:accredited_organization) }

    it {
      expect(subject).to validate_uniqueness_of(:accredited_organization_id)
        .scoped_to(:accredited_individual_id)
        .ignoring_case_sensitivity
    }
  end
end
