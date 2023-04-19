# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/intent_to_file/intent_to_file_provider'

RSpec.describe IntentToFileProvider do
  let(:current_user) { build(:user) }

  it 'always raises an error on the IntentToFileProvider base module - get intent to file' do
    expect do
      IntentToFileProvider.get_intent_to_file
    end.to raise_error NotImplementedError
  end

  it 'always raises an error on the IntentToFileProvider base module - create intent to file' do
    expect do
      IntentToFileProvider.create_intent_to_file('')
    end.to raise_error NotImplementedError
  end
end
