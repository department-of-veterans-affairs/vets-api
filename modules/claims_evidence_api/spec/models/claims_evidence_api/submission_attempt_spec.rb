# frozen_string_literal: true

require 'rails_helper'
require 'models/_shared_examples/submission_attempt'

RSpec.describe ClaimsEvidenceApi::SubmissionAttempt, type: :model do
  it_behaves_like 'a SubmissionAttempt model'
end
