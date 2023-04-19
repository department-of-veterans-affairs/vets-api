# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/rated_disabilities/rated_disabilities_provider'

RSpec.describe RatedDisabilitiesProvider do
  let(:current_user) { build(:user) }

  it 'always raises an error on the RatedDisabilitiesProvider base module' do
    expect do
      RatedDisabilitiesProvider.get_rated_disabilities
    end.to raise_error NotImplementedError
  end
end
