# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::EducationBenefitsClaimsController, type: :controller do
  it_should_behave_like 'a controller that deletes an InProgressForm', 'education_benefits_claim', 'va1990', '22-1990'
end
