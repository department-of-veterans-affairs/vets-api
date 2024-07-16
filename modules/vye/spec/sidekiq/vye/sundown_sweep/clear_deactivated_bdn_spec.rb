# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::SundownSweep::ClearDeactivatedBdn, type: :worker do
  it 'checks the existence of described_class' do
    expect(described_class).to be_a(Class)
  end
end
