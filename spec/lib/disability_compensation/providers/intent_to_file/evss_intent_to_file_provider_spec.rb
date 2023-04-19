# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/intent_to_file/evss_intent_to_file_provider'
require 'support/disability_compensation_form/shared_examples/intent_to_file_provider'

RSpec.describe EvssIntentToFileProvider do
  let(:current_user) { build(:disabilities_compensation_user) }

  it_behaves_like 'intent to file provider'
end
