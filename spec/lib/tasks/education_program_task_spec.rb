# frozen_string_literal: true
require 'rails_helper'

describe 'rake edu:education_program', type: :task do
  before do
    create(:education_benefits_claim)
    create(:education_benefits_claim_with_custom_form,
      custom_form: {
        educationProgram: {
          name: 'foo'
        }
      }
    )
  end

  it 'should convert the claims' do
    task.execute
    binding.pry; fail
  end
end
