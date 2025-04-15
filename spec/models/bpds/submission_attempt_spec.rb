# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bpds::SubmissionAttempt, type: :model do
  it { is_expected.to validate_presence_of :bpds_submission_id }
end
