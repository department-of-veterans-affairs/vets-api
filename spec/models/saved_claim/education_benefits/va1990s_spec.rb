# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA1990s do
  let(:instance) { build(:va1990s_full_form) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-1990S')
end
