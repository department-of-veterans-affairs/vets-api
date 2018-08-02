# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GIBillFeedback, type: :model do
  let(:gi_bill_feedback) { build(:gi_bill_feedback) }

  describe '#find' do
    it 'should be able to find created models' do
      gi_bill_feedback.save!
      guid = gi_bill_feedback.guid

      expect(described_class.find(guid).guid).to eq(guid)
    end
  end

  describe '#transform_form' do
    it 'should transform the form to the right format' do
      gi_bill_feedback.user = create(:user)
      gi_bill_feedback.transform_form
    end
  end
end
