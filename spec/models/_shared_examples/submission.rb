# frozen_string_literal: true

shared_examples_for 'a Submission model' do
  it { is_expected.to validate_presence_of :form_id }
end
