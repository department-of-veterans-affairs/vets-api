# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Feedback, type: :model do
  it 'requires description' do
    feedback = Feedback.new(target_page: '/somewhere')
    expect(feedback).to be_invalid
    expect(feedback.errors).to include(:description)
  end

  it 'requires target_page' do
    feedback = Feedback.new(description: +'i like this page')
    expect(feedback).to be_invalid
    expect(feedback.errors).to include(:target_page)
  end

  describe '#initialize' do
    context 'with sensitive data in the description' do
      subject(:feedback) do
        described_class.new(
          description: +'I am joe@vet.com, with ssn 999-33-4445, thanks.',
          email: 'joe@vet.com',
          target_page: '/users'
        )
      end
      it 'removes ssn and email' do
        expect(feedback.description).to eq('I am [FILTERED EMAIL], with ssn [FILTERED SSN], thanks.')
      end

      it 'should be valid' do
        expect(feedback).to be_valid
      end
    end
  end
end
