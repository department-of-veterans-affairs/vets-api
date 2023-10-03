# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA1990s do
  %w[kitchen_sink simple].each do |form|
    test_spool_file('1990s', form)
  end
end
