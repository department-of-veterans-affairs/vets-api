# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::PensionClaimsController, type: :controller do
  it_should_behave_like 'a controller that deletes an InProgressForm', 'pension_claim', 'pension_claim', '21P-527EZ'
end
