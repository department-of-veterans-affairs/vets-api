# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA10203dny do
  subject { described_class.new(education_benefits_claim) }

  let(:education_benefits_claim) { build(:va10203dny).education_benefits_claim }

  %w[kitchen_sink minimal].each do |test_application|
    test_spool_file('10203dny', test_application)
  end
end
