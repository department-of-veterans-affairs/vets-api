# frozen_string_literal: true
require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA1990 do
  it_should_behave_like 'saved_claim'
end
