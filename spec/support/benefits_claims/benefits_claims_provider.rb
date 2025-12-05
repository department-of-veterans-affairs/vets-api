# frozen_string_literal: true

require 'rails_helper'

shared_examples 'benefits claims provider' do
  subject { described_class.new(current_user) }

  it { is_expected.to respond_to(:get_claims) }
  it { is_expected.to respond_to(:get_claim) }
end
