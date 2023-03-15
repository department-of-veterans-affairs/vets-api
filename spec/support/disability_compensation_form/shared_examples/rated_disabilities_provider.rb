# frozen_string_literal: true

require 'rails_helper'

shared_examples 'rated disabilities provider' do
  # this is used to instantiate any RateDisabilitiesProvider with a current_user
  subject { described_class.new(current_user) }

  it { is_expected.to respond_to(:get_rated_disabilities) }
end
