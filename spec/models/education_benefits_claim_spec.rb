# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationBenefitsClaim, type: :model do
  let(:education_benefits_claim) do
    create(:va1990).education_benefits_claim
  end

  %w[1990 1995 1990e 5490 5495 1990n].each do |form_type|
    method = "is_#{form_type}?"

    describe "##{method}" do
      it "should return false when it's not the right type" do
        education_benefits_claim.saved_claim.form_id = 'foo'
        expect(education_benefits_claim.public_send(method)).to eq(false)
      end

      it "should return true when it's the right type" do
        education_benefits_claim.saved_claim.form_id = "22-#{form_type.upcase}"
        expect(education_benefits_claim.public_send(method)).to eq(true)
      end
    end
  end

  describe '#form_type' do
    it 'should return the form type' do
      expect(education_benefits_claim.form_type).to eq('1990')
    end
  end

  describe '#regional_office' do
    it 'should return the regional office' do
      expect(education_benefits_claim.regional_office).to eq(
        "Eastern Region\nVA Regional Office\nP.O. Box 4616\nBuffalo, NY 14240-4616"
      )
    end
  end

  describe '#confirmation_number' do
    it 'should let you look up a claim from the confirmation number' do
      expect(
        described_class.find(education_benefits_claim.confirmation_number.gsub('V-EBC-', '').to_i)
      ).to eq(education_benefits_claim)
    end
  end

  describe '#update_education_benefits_submission_status' do
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
    subject { create(:va1990_western_region) }

    let(:submission_attributes) do
      {
        'region' => 'eastern',
        'chapter33' => false,
        'chapter30' => false,
        'chapter1606' => false,
        'chapter32' => false,
        'chapter35' => false,
        'status' => 'submitted',
        'transfer_of_entitlement' => false,
        'chapter1607' => false,
        'education_benefits_claim_id' => subject.education_benefits_claim.id
      }
    end

    def associated_submission
      subject.education_benefits_claim.education_benefits_submission.attributes.except('id', 'created_at', 'updated_at')
    end

    it 'should create an education benefits submission after submission' do
      expect do
        subject
      end.to change { EducationBenefitsSubmission.count }.by(1)

      expect(associated_submission).to eq(
        submission_attributes.merge(
          'region' => 'western',
          'chapter1606' => true,
          'form_type' => '1990'
        )
      )
    end

    context 'with a form type of 1995' do
      subject do
        create(:va1995)
      end

      it 'should create a submission' do
        subject

        expect(associated_submission).to eq(
          submission_attributes.merge(
            'form_type' => '1995',
            'transfer_of_entitlement' => true
          )
        )
      end
    end

    context 'with a form type of 1990e' do
      subject do
        create(:va1990e)
      end

      it 'should create a submission' do
        subject

        expect(associated_submission).to eq(
          submission_attributes.merge(
            'chapter33' => true,
            'form_type' => '1990e'
          )
        )
      end
    end

    context 'with a form type of 5490' do
      subject do
        create(:va5490)
      end

      it 'should create a submission' do
        subject

        expect(associated_submission).to eq(
          submission_attributes.merge(
            'chapter35' => true,
            'form_type' => '5490'
          )
        )
      end
    end

    context 'with a form type of 1990n' do
      subject do
        create(:va1990n)
      end

      it 'should create a submission' do
        subject

        expect(associated_submission).to eq(
          submission_attributes.merge(
            'form_type' => '1990n'
          )
        )
      end
    end

    context 'with a form type of 5495' do
      subject do
        create(:va5495)
      end

      it 'should create a submission' do
        subject

        expect(associated_submission).to eq(
          submission_attributes.merge(
            'form_type' => '5495',
            'chapter35' => true
          )
        )
      end
    end

    it "shouldn't create a submission after save if it was already submitted" do
      subject.education_benefits_claim.update_attributes!(processed_at: Time.zone.now)
      expect(EducationBenefitsSubmission.count).to eq(1)
    end
  end

  describe '#copy_from_previous_benefits' do
    let(:form) do
      {
        previousBenefits: {
          veteranFullName: 'joe',
          vaFileNumber: '123',
          veteranSocialSecurityNumber: '321'
        }
      }
    end

    subject do
      saved_claim = build(:va1990, form: form.to_json)

      education_benefits_claim.instance_variable_set(:@application, saved_claim.open_struct_form)
      education_benefits_claim.copy_from_previous_benefits
      education_benefits_claim.open_struct_form
    end

    context 'when currentSameAsPrevious is false' do
      before do
        form[:currentSameAsPrevious] = false
      end

      it 'shouldnt copy fields from previous benefits' do
        %w[veteranFullName vaFileNumber veteranSocialSecurityNumber].each do |attr|
          expect(subject.public_send(attr)).to eq(nil)
        end
      end
    end

    context 'when currentSameAsPrevious is true' do
      before do
        form[:currentSameAsPrevious] = true
      end

      it 'should copy fields from previous benefits' do
        expect(subject.veteranFullName).to eq('joe')
        expect(subject.vaFileNumber).to eq('123')
        expect(subject.veteranSocialSecurityNumber).to eq('321')
      end
    end
  end

  describe 'reprocess_at' do
    it 'raises an error if an invalid region is entered' do
      expect { education_benefits_claim.reprocess_at('nowhere') }.to raise_error(/Invalid region/)
    end

    it 'sets a record for processing' do
      expect do
        education_benefits_claim.reprocess_at('western')
      end.to change { education_benefits_claim.regional_processing_office }.from('eastern').to('western')
      expect(education_benefits_claim.processed_at).to be nil
    end
  end
end
