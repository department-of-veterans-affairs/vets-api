# frozen_string_literal: true

shared_examples_for 'a SubmissionAttempt model' do
  it { is_expected.to validate_presence_of :submission }
end
