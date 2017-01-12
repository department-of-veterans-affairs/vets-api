# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationBenefitsClaim, type: :model do
  let(:attributes) do
    {
      form: { chapter30: true, privacyAgreementAccepted: true }.to_json
    }
  end
  subject { described_class.new(attributes) }

  describe 'validations' do
    it 'should validate presence of form' do
      expect_attr_valid(subject, :form)
      subject.form = nil
      expect_attr_invalid(subject, :form, "can't be blank")
    end

    describe '#form_must_be_string' do
      before do
        attributes[:form] = JSON.parse(attributes[:form])
      end

      it 'should not allow a hash to be passed in for form' do
        expect_attr_invalid(subject, :form, 'must be a json string')
      end
    end

    it 'should validate inclusion of form_type' do
      %w(1990 1995).each do |form_type|
        subject.form_type = form_type
        expect_attr_valid(subject, :form_type)
      end

      subject.form_type = 'foo'
      expect_attr_invalid(subject, :form_type, 'is not included in the list')
    end

    describe '#form_matches_schema' do
      context 'verifies that privacyAgreementAccepted is true' do
        [[true, true], [false, false], [nil, false]].each do |value, answer|
          it "when the value is #{value}" do
            attributes[:form] = {
              privacyAgreementAccepted: value
            }.to_json
            assert_equal answer, subject.valid?
          end
        end
      end

      it 'should be valid on a valid form' do
        expect_attr_valid(subject, :form)
      end

      context 'with an invalid form' do
        before do
          attributes[:form] = {
            chapter30: 0,
            privacyAgreementAccepted: true
          }.to_json
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

  %w(1990 1995).each do |form_type|
    method = "is_#{form_type}?"

    describe "##{method}" do
      it "should return false when it's not the right type" do
        subject.form_type = 'foo'
        expect(subject.public_send(method)).to eq(false)
      end

      it "should return true when it's the right type" do
        subject.form_type = form_type
        expect(subject.public_send(method)).to eq(true)
      end
    end
  end

  describe 'form field' do
    it 'should encrypt and decrypt the form field' do
      subject.save!

      expect(subject['form']).to eq(nil)
      expect(subject.form).to eq(attributes[:form])

      %w(encrypted_form encrypted_form_iv).each do |attr|
        expect(subject[attr].present?).to eq(true)
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

  describe '#regional_office' do
    it 'should return the regional office' do
      expect(subject.regional_office).to eq("Eastern Region\nVA Regional Office\nP.O. Box 4616\nBuffalo, NY 14240-4616")
    end
  end

  describe '#confirmation_number' do
    it 'should let you look up a claim from the confirmation number' do
      subject.save!
      expect(
        described_class.find(subject.confirmation_number.gsub('vets_gov_education_benefits_claim_', '').to_i)
      ).to eq(subject)
    end
  end

  describe '#update_education_benefits_submission_status' do
    let(:education_benefits_claim) { create(:education_benefits_claim) }

    subject do
      education_benefits_claim.update_attributes!(processed_at: Time.zone.now)
      education_benefits_claim
    end

    it 'should update the education_benefits_submission status' do
      expect(subject.education_benefits_submission.status).to eq('processed')
    end

    context 'when the education_benefits_submission is missing' do
      before do
        education_benefits_claim.education_benefits_submission.destroy
        education_benefits_claim.reload
      end

      it 'the callback shouldnt raise error' do
        subject
      end
    end
  end

  describe '#create_education_benefits_submission' do
    subject { create(:education_benefits_claim_western_region) }

    def associated_submission
      subject.education_benefits_submission.attributes.except('id', 'created_at', 'updated_at')
    end

    it 'should create an education benefits submission after submission' do
      expect do
        subject
      end.to change { EducationBenefitsSubmission.count }.by(1)

      expect(associated_submission).to eq(
        'region' => 'western',
        'chapter33' => false,
        'chapter30' => false,
        'chapter1606' => true,
        'chapter32' => false,
        'status' => 'submitted',
        'form_type' => '1990',
        'education_benefits_claim_id' => subject.id
      )
    end

    context 'with a form type of 1995' do
      subject do
        create(:education_benefits_claim_1995)
      end

      it 'should create a submission' do
        subject

        expect(associated_submission).to eq(
          'region' => 'eastern',
          'chapter33' => false,
          'chapter30' => false,
          'chapter1606' => false,
          'chapter32' => false,
          'status' => 'submitted',
          'education_benefits_claim_id' => subject.id,
          'form_type' => '1995'
        )
      end
    end

    it "shouldn't create a submission after save if it was already submitted" do
      subject.update_attributes!(processed_at: Time.zone.now)
      expect(EducationBenefitsSubmission.count).to eq(1)
    end
  end

  describe 'reprocess_at' do
    it 'raises an error if an invalid region is entered' do
      expect { subject.reprocess_at('nowhere') }.to raise_error(/Invalid region/)
    end

    it 'sets a record for processing' do
      subject.save
      expect do
        subject.reprocess_at('western')
      end.to change { subject.regional_processing_office }.from('eastern').to('western')
      expect(subject.processed_at).to be nil
    end
  end
end
