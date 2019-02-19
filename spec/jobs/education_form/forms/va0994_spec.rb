# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA0994 do
  let(:education_benefits_claim) { build(:va0994).education_benefits_claim }

  subject { described_class.new(education_benefits_claim) }

  %w[kitchen_sink prefill simple].each do |form|
    test_spool_file('0994', form)
  end
end
