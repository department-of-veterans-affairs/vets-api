# frozen_string_literal: true

require 'rails_helper'

shared_examples 'claims service provider' do
  # this is used to instantiate any Claim Service with a current_user
  subject { described_class.new(current_user) }

  it { is_expected.to respond_to(:all_claims) }
end
