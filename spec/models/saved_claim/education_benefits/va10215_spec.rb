# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA10215 do
  let(:instance) { build(:va10215) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-10215')
end
