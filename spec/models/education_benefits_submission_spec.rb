# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationBenefitsSubmission, type: :model do
  let(:attributes) do
    {
      region: 'eastern'
    }
  end
  subject { described_class.new(attributes) }

  describe 'validations' do
    it 'should validate region is correct' do
      subject.region = 'western'
      expect_attr_valid(subject, :region)

      subject.region = 'canada'
      expect_attr_invalid(subject, :region, 'is not included in the list')
    end
  end
end
