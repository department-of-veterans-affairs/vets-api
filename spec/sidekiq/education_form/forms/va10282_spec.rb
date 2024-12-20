# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA10282 do
  %w[minimal].each do |test_application|
    test_excel_file('10282', test_application)
  end
end
