# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationBenefitsClaim, type: :model do
  let(:attributes) do
    {
      form: { chapter30: true }
    }
  end
  subject { described_class.new(attributes) }

  describe 'validations' do
    it 'should validate presence of form' do
      expect_attr_valid(subject, :form)
      subject.form = nil
      expect_attr_invalid(subject, :form, "can't be blank")
    end

    describe '#form_matches_schema' do
      it 'should be valid on a valid form' do
        expect_attr_valid(subject, :form)
      end

      context 'with an invalid form' do
        before do
          attributes[:form] = {
            chapter30: 0
          }
        end

        it 'should have a json schema error' do
          subject.valid?
          form_errors = subject.errors[:form]

          expect(form_errors.size).to eq(1)
          expect(
            form_errors[0].include?(
              "The property '#/chapter30' of type Fixnum did not match the following type: boolean"
            )
          ).to eq(true)
        end
      end
    end
  end

  describe '#set_submitted_at' do
    it 'should set the submitted_at date before validation on create' do
      Timecop.freeze do
        expect(subject.submitted_at).to eq(nil)
        subject.valid?
        expect(subject.submitted_at).to eq(Time.zone.now)
      end
    end

    context 'with a created model' do
      let(:time) { 1.day.ago }
      subject { described_class.create!(attributes) }

      before do
        subject.update_column(:submitted_at, time)
      end

      it 'should not set the submitted_at again' do
        subject.valid?
        expect(subject.submitted_at).to eq(time)
      end
    end
  end
end
