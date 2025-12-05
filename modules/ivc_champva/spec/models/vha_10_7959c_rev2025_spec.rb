# frozen_string_literal: true

require 'rails_helper'
require_relative 'vha_10_7959c_shared_examples'

RSpec.describe IvcChampva::VHA107959cRev2025 do
  it_behaves_like 'form model 10_7959C', '10-7959C-REV2025'
end
