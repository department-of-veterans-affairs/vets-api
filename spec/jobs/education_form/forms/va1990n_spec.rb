# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA1990n do
  %w[kitchen_sink simple].each do |test_application|
    test_spool_file('1990n', test_application)
  end
end
