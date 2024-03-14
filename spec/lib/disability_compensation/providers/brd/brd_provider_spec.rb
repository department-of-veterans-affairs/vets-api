# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/brd/brd_provider'

RSpec.describe BRDProvider do
  let(:current_user) { build(:user) }

  it 'always raises an error on the BRDProvider base module' do
    expect do
      BRDProvider.get_separation_locations
    end.to raise_error NotImplementedError
  end
end
