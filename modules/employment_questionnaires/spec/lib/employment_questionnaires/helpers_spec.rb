# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmploymentQuestionnaires::Helpers do
  subject { dummy_class.new }

  let(:dummy_class) { Class.new { include EmploymentQuestionnaires::Helpers } }
end
