# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/rated_disabilities/lighthouse_rated_disabilities_provider'
require 'support/disability_compensation_form/shared_examples/rated_disabilities_provider'

RSpec.describe LighthouseRatedDisabilitiesProvider do
  let(:current_user) { build(:user, :loa3) }

  # TODO: update when the LighthouseRatedDisabilitiesProvider is implemented
  it 'behaves like a RatedDisabilitiesProvider' do
    # it_behaves_like :rated_disabilities_provider
    expect do
      LighthouseRatedDisabilitiesProvider.new(current_user)
    end.to raise_error NotImplementedError
  end
end
