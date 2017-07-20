# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationBenefitsClaim, type: :model do
  let(:attributes) do
    {
      form: {
        chapter30: true,
        veteranFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        privacyAgreementAccepted: true
      }.to_json
    }
  end
  subject { described_class.new(attributes) }

  describe '#regional_office' do
    it 'should return the regional office' do
      expect(subject.regional_office).to eq("Eastern Region\nVA Regional Office\nP.O. Box 4616\nBuffalo, NY 14240-4616")
    end
  end

  describe '#confirmation_number' do
    it 'should let you look up a claim from the confirmation number' do
      subject.save!
      expect(
        described_class.find(subject.confirmation_number.gsub('V-EBC-', '').to_i)
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
        'education_benefits_claim_id' => subject.id
      }
    end

    def associated_submission
      subject.education_benefits_submission.attributes.except('id', 'created_at', 'updated_at')
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
        create(:education_benefits_claim_1995)
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
        create(:education_benefits_claim_1990e)
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
        create(:education_benefits_claim_5490)
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
        create(:education_benefits_claim_1990n)
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
        create(:education_benefits_claim_5495)
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
      subject.update_attributes!(processed_at: Time.zone.now)
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
      attributes[:form] = form.to_json
      education_benefits_claim = described_class.new(attributes)
      allow(education_benefits_claim).to receive(:transform_form)

      education_benefits_claim.open_struct_form
      education_benefits_claim.copy_from_previous_benefits
      education_benefits_claim.open_struct_form
    end

    context 'when currentSameAsPrevious is false' do
      before do
        form[:currentSameAsPrevious] = false
      end

      it 'shouldnt copy fields from previous benefits' do
        %w(veteranFullName vaFileNumber veteranSocialSecurityNumber).each do |attr|
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
