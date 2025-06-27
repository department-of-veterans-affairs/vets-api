# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA10297 do
  test_spool_file('10297', 'simple')
end
