# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/rated_disabilities/lighthouse_rated_disabilities_provider'
require 'support/disability_compensation_form/shared_examples/rated_disabilities_provider'

RSpec.describe LighthouseRatedDisabilitiesProvider do
  let(:current_user) { build(:user, :loa3) }

  it_behaves_like 'rated disabilities provider'
end
