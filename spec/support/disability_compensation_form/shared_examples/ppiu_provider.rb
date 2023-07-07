# frozen_string_literal: true

require 'rails_helper'

shared_examples 'ppiu direct deposit provider' do
  # this is used to instantiate any PPIUProvider with a current_user
  subject { described_class.new(current_user) }

  it { is_expected.to respond_to(:get_payment_information) }
end
