# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA5495 do
  let(:instance) { FactoryBot.build(:va5495) }
  it_should_behave_like 'saved_claim'

  validate_inclusion(:form_id, '22-5495')
end
