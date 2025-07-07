# frozen_string_literal: true

require 'rails_helper'
require 'support/models/shared_examples/submission'

RSpec.describe Lighthouse::Submission, type: :model do
  it_behaves_like 'a Submission model'
end
