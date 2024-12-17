# frozen_string_literal: true

require_relative '../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequest, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:claimant).class_name('UserAccount') }
    it { is_expected.to have_one(:power_of_attorney_form) }
    it { is_expected.to have_one(:resolution) }
  end
end
