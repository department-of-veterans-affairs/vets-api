# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA10203 do
  let(:education_benefits_claim) { build(:va10203).education_benefits_claim }

  %w[kitchen_sink simple].each do |test_application|
    test_spool_file('10203', test_application)
  end
end
