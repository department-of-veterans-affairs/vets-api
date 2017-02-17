# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::Forms::VA1995 do
  let(:education_benefits_claim) { build(:education_benefits_claim_1995) }

  subject { described_class.new(education_benefits_claim) }

  SAMPLE_APPLICATIONS = [
    :minimal, :kitchen_sink
  ].freeze

  it 'has a 22-1995 type' do
    expect(described_class::TYPE).to eq('22-1995')
  end

  # For each sample application we have, format it and compare it against a 'known good'
  # copy of that submission. This technically covers all the helper logic found in the
  # `Form` specs, but are a good safety net for tracking how forms change over time.
  SAMPLE_APPLICATIONS.each do |application_name|
    test_spool_file('1995', application_name)
  end
end
