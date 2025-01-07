# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA210845 do
  it_behaves_like 'zip_code_is_us_based', %w[authorizer_address person_address organization_address]
end
