# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA10216 do
  %w[kitchen_sink simple].each do |test_application|
    test_spool_file('10216', test_application)
  end
end
