# frozen_string_literal: true

require 'rails_helper'

shared_examples 'claim letters provider' do
  # this is used to instantiate any Claim Letter Provider with a current_user
  subject { described_class.new(current_user) }

  it { is_expected.to respond_to(:get_letters) }
  it { is_expected.to respond_to(:get_letter) }
end
