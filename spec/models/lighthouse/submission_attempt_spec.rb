# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::SubmissionAttempt, type: :model do
  it { is_expected.to validate_presence_of :submission }
end
