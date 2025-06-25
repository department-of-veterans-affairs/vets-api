# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA10297 do
  subject { described_class.new(education_benefits_claim) }

  let(:education_benefits_claim) { build(:va10297).education_benefits_claim }

  %w[kitchen_sink prefill simple].each do |form|
    test_spool_file('10297', form)
  end
end
