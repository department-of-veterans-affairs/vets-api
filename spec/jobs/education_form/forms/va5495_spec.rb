# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA5495 do
  %w[kitchen_sink simple].each do |test_application|
    test_spool_file('5495', test_application)
  end
end
