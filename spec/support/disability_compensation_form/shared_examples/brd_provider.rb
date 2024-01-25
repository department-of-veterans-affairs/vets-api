# frozen_string_literal: true

require 'rails_helper'

shared_examples 'brd provider' do
  # this is used to instantiate any BRD with a current_user
  subject { described_class.new(current_user) }

  it { is_expected.to respond_to(:get_separation_locations) }
end
