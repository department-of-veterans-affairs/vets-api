# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA1990e do
  let(:instance) { FactoryBot.build(:va1990e) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-1990E')
end
