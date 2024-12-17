# frozen_string_literal: true

require_relative '../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:creator).class_name('UserAccount') }
    it { is_expected.to have_one(:power_of_attorney_request_resolution) }
  end
end
