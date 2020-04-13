# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA10203 do
  subject { described_class.new(education_benefits_claim) }
  let(:education_benefits_claim) { build(:va10203).education_benefits_claim }
end
