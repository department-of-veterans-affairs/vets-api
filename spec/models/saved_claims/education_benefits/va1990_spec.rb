# frozen_string_literal: true
require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA1990 do
  let(:instance) { FactoryGirl.build(:va1990) }
  it_should_behave_like 'saved_claim'

  describe 'validations' do
    subject do
      described_class.new
    end

    it 'should validate form_id' do
      subject.form_id = "22-1990"
      expect_attr_valid(subject, :form_id)

      subject.form_id = 'foo'
      expect_attr_invalid(subject, :form_id, 'is not included in the list')
    end
  end
end
