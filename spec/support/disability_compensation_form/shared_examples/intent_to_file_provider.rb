# frozen_string_literal: true

require 'rails_helper'

shared_examples 'intent to file provider' do
  # this is used to instantiate any IntentToFileProvider with a current_user
  subject { described_class.new(current_user) }

  it { is_expected.to respond_to(:get_intent_to_file) }
  it { is_expected.to respond_to(:create_intent_to_file) }
end
