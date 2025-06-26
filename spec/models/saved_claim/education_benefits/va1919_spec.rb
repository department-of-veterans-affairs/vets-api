# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA1919 do
  let(:instance) { build(:va1919) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-1919')
end
