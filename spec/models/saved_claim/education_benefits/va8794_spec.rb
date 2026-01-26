# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA8794 do
  let(:instance) { build(:va8794) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-8794')
end
