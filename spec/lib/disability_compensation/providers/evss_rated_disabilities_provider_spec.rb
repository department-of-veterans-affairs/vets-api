# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/rated_disabilities/evss_rated_disabilities_provider'
require 'support/disability_compensation_form/shared_examples/rated_disabilities_provider'

RSpec.describe EvssRatedDisabilitiesProvider do
  let(:current_user) { build(:disabilities_compensation_user) }

  it_behaves_like 'rated disabilities provider'
end
