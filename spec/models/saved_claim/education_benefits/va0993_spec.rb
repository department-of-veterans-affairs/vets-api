# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA0993 do
  let(:instance) { build(:va0993) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-0993')
end
