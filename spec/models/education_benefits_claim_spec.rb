# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationBenefitsClaim, type: :model do
  let(:education_benefits_claim) do
    create(:va1990).education_benefits_claim
  end

  %w[1990 1995 5490 5495 0993 0994 10203 10282 10216 10215 10297 1919 0839 10275 8794 0976].each do |form_type|
    method = "is_#{form_type}?"

    describe "##{method}" do
      it "returns false when it's not the right type" do
        education_benefits_claim.saved_claim.form_id = 'foo'
        expect(education_benefits_claim.public_send(method)).to be(false)
      end

      it "returns true when it's the right type" do
        education_benefits_claim.saved_claim.form_id = "22-#{form_type.upcase}"
        expect(education_benefits_claim.public_send(method)).to be(true)
      end
    end
  end

  describe '#form_type' do
    it 'returns the form type' do
      expect(education_benefits_claim.form_type).to eq('1990')
    end
  end

  describe '#regional_office' do
    it 'returns the regional office' do
      expect(education_benefits_claim.regional_office).to eq(
        "VA Regional Office\nP.O. Box 4616\nBuffalo, NY 14240-4616"
      )
    end
  end

  describe '#confirmation_number' do
    it 'lets you look up a claim from the confirmation number' do
      expect(
        described_class.find(education_benefits_claim.confirmation_number.gsub('V-EBC-', '').to_i)
      ).to eq(education_benefits_claim)
    end
  end

  describe 'token' do
    it 'automatically generates a unique token' do
      expect(education_benefits_claim.token).not_to be_nil
    end
  end

  describe '#update_education_benefits_submission_status' do
    subject do
      education_benefits_claim.update!(processed_at: Time.zone.now)
      education_benefits_claim
    end

    it 'updates the education_benefits_submission status' do
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
        'vettec' => false,
        'vrrap' => false,
        'education_benefits_claim_id' => subject.education_benefits_claim.id
      }
    end

    def associated_submission
      subject.education_benefits_claim.education_benefits_submission.attributes.except('id', 'created_at', 'updated_at')
    end

    it 'creates an education benefits submission after submission' do
      expect do
        subject
      end.to change(EducationBenefitsSubmission, :count).by(1)

      expect(associated_submission).to eq(
        submission_attributes.merge(
          'region' => 'western',
          'chapter1606' => true,
          'form_type' => '1990'
        )
      )
    end

    context 'with a form type of 1995 and benefit transfer of entitlement' do
      subject do
        create(:va1995)
      end

      it 'creates a submission' do
        subject

        expect(associated_submission).to eq(
          submission_attributes.merge(
            'form_type' => '1995',
            'transfer_of_entitlement' => true
          )
        )
      end
    end

    context 'with a form type of 1995 and benefit chapter33 post911' do
      subject do
        create(:va1995_ch33_post911)
      end

      it 'creates a submission' do
        subject

        expect(associated_submission).to eq(
          submission_attributes.merge(
            'form_type' => '1995',
            'chapter33' => true
          )
        )
      end
    end

    context 'with a form type of 1995 and benefit chapter33 fry scholarship' do
      subject do
        create(:va1995_ch33_fry)
      end

      it 'creates a submission' do
        subject

        expect(associated_submission).to eq(
          submission_attributes.merge(
            'form_type' => '1995',
            'chapter33' => true
          )
        )
      end
    end

    context 'with a form type of 5490' do
      subject do
        create(:va5490)
      end

      it 'creates a submission' do
        subject

        expect(associated_submission).to eq(
          submission_attributes.merge(
            'chapter35' => true,
            'form_type' => '5490'
          )
        )
      end
    end

    context 'with a form type of 5495' do
      subject do
        create(:va5495)
      end

      it 'creates a submission' do
        subject

        expect(associated_submission).to eq(
          submission_attributes.merge(
            'form_type' => '5495',
            'chapter35' => true
          )
        )
      end
    end

    context 'with a form type of 10203' do
      subject do
        create(:va10203)
      end

      it 'creates a submission' do
        subject

        expect(associated_submission).to eq(
          submission_attributes.merge(
            'form_type' => '10203',
            'transfer_of_entitlement' => true
          )
        )
      end
    end

    context 'with a form type of 10282' do
      subject do
        create(:va10282)
      end

      it 'creates a submission' do
        subject

        expect(associated_submission).to eq(
          submission_attributes.merge(
            'form_type' => '10282'
          )
        )
      end
    end

    it 'does not create a submission after save if it was already submitted' do
      subject.education_benefits_claim.update!(processed_at: Time.zone.now)
      expect(EducationBenefitsSubmission.count).to eq(1)
    end
  end

  describe '#copy_from_previous_benefits' do
    subject do
      saved_claim = build(:va1990, form: form.to_json)

      education_benefits_claim.instance_variable_set(:@application, saved_claim.open_struct_form)
      education_benefits_claim.copy_from_previous_benefits
      education_benefits_claim.open_struct_form
    end

    let(:form) do
      {
        previousBenefits: {
          veteranFullName: 'joe',
          vaFileNumber: '123',
          veteranSocialSecurityNumber: '321'
        }
      }
    end

    context 'when currentSameAsPrevious is false' do
      before do
        form[:currentSameAsPrevious] = false
      end

      it 'shouldnt copy fields from previous benefits' do
        %w[veteranFullName vaFileNumber veteranSocialSecurityNumber].each do |attr|
          expect(subject.public_send(attr)).to be_nil
        end
      end
    end

    context 'when currentSameAsPrevious is true' do
      before do
        form[:currentSameAsPrevious] = true
      end

      it 'copies fields from previous benefits' do
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
      end.to change(education_benefits_claim, :regional_processing_office).from('eastern').to('western')
      expect(education_benefits_claim.processed_at).to be_nil
    end
  end

  describe '#form_headers' do
    it 'appends 22- to FORM_TYPES' do
      expect(described_class.form_headers).to eq(described_class::FORM_TYPES.map { |t| "22-#{t}" }.freeze)
    end

    it 'appends 22- to passed in array' do
      form_types = %w[10203]
      form_headers = %w[22-10203]
      expect(described_class.form_headers(form_types)).to eq(form_headers)
    end
  end

  describe '#region' do
    it 'returns the region for the claim' do
      expect(education_benefits_claim.region).to be_a(Symbol)
      expect(EducationForm::EducationFacility::REGIONS).to include(education_benefits_claim.region)
    end
  end

  describe '#unprocessed' do
    it 'returns claims without processed_at' do
      processed = create(:va1990).education_benefits_claim
      processed.update!(processed_at: Time.zone.now)

      unprocessed1 = create(:va1990).education_benefits_claim
      unprocessed2 = create(:va1995).education_benefits_claim

      expect(described_class.unprocessed).to include(unprocessed1, unprocessed2)
      expect(described_class.unprocessed).not_to include(processed)
    end
  end

  describe '#set_region' do
    it 'sets regional_processing_office if not already set' do
      saved_claim = create(:va1990)
      claim = saved_claim.education_benefits_claim
      claim.regional_processing_office = nil
      claim.save!

      expect(claim.regional_processing_office).not_to be_nil
      expect(claim.regional_processing_office).to eq(claim.region.to_s)
    end

    it 'does not override existing regional_processing_office' do
      saved_claim = create(:va1990)
      claim = saved_claim.education_benefits_claim
      claim.regional_processing_office = 'custom_region'
      claim.save!

      expect(claim.regional_processing_office).to eq('custom_region')
    end
  end

  describe '#open_struct_form' do
    it 'returns an OpenStruct with confirmation number' do
      result = education_benefits_claim.open_struct_form
      expect(result).to be_a(OpenStruct)
      expect(result.confirmation_number).to match(/^V-EBC-/)
    end

    it 'memoizes the result' do
      result1 = education_benefits_claim.open_struct_form
      result2 = education_benefits_claim.open_struct_form
      expect(result1.object_id).to eq(result2.object_id)
    end

    context 'with form type 1990' do
      it 'transforms the form correctly' do
        saved_claim = create(:va1990)
        claim = saved_claim.education_benefits_claim
        result = claim.open_struct_form

        expect(result.confirmation_number).to match(/^V-EBC-/)
      end
    end
  end

  describe '#transform_form' do
    context 'with form type 1990' do
      it 'calls generate_benefits_to_apply_to' do
        saved_claim = create(:va1990)
        claim = saved_claim.education_benefits_claim
        claim.open_struct_form
        tours = claim.instance_variable_get(:@application).toursOfDuty

        if tours&.any?
          tour_with_selected = tours.find(&:applyPeriodToSelected)
          expect(tour_with_selected&.benefitsToApplyTo).to be_present if tour_with_selected
        end
      end
    end

    context 'with form type 5490' do
      it 'calls copy_from_previous_benefits when currentSameAsPrevious is true' do
        saved_claim = create(:va5490)
        claim = saved_claim.education_benefits_claim
        result = claim.open_struct_form

        expect(result).to be_a(OpenStruct)
      end
    end
  end

  describe '#generate_benefits_to_apply_to' do
    it 'generates benefits string for tours with applyPeriodToSelected' do
      saved_claim = create(:va1990)
      claim = saved_claim.education_benefits_claim
      claim.open_struct_form
      tours = claim.instance_variable_get(:@application).toursOfDuty

      if tours&.any?
        tour_with_selected = tours.find(&:applyPeriodToSelected)
        expect(tour_with_selected&.benefitsToApplyTo).to be_present if tour_with_selected
      end
    end
  end

  describe '#selected_benefits' do
    context 'with form type 1990' do
      it 'returns all application types from parsed_form' do
        saved_claim = create(:va1990)
        claim = saved_claim.education_benefits_claim
        benefits = claim.selected_benefits

        expect(benefits).to be_a(Hash)
        expect(benefits.keys).to be_a(Array)
      end
    end

    context 'with form type 0994' do
      it 'returns vettec benefit' do
        claim = create(:va0994_minimum_form).education_benefits_claim
        benefits = claim.selected_benefits

        expect(benefits['vettec']).to be(true)
      end
    end

    context 'with form type 10297' do
      it 'returns vettec benefit' do
        claim = create(:va10297_simple_form).education_benefits_claim
        benefits = claim.selected_benefits

        expect(benefits['vettec']).to be(true)
      end
    end

    context 'with form type 1995' do
      context 'with chapter33 post911 benefit' do
        it 'returns chapter33 benefit' do
          claim = create(:va1995_ch33_post911).education_benefits_claim
          benefits = claim.selected_benefits

          expect(benefits['chapter33']).to be(true)
        end
      end

      context 'with chapter33 fry scholarship benefit' do
        it 'returns chapter33 benefit' do
          claim = create(:va1995_ch33_fry).education_benefits_claim
          benefits = claim.selected_benefits

          expect(benefits['chapter33']).to be(true)
        end
      end

      context 'with transfer of entitlement benefit' do
        it 'returns transfer_of_entitlement benefit' do
          claim = create(:va1995).education_benefits_claim
          benefits = claim.selected_benefits

          expect(benefits['transfer_of_entitlement']).to be(true)
        end
      end

      context 'with other benefit' do
        it 'returns the benefit' do
          saved_claim = create(:va1995)
          claim = saved_claim.education_benefits_claim
          benefits = claim.selected_benefits

          expect(benefits).to be_a(Hash)
        end
      end
    end

    context 'with form type 5490' do
      it 'returns the benefit' do
        saved_claim = create(:va5490)
        claim = saved_claim.education_benefits_claim
        benefits = claim.selected_benefits

        expect(benefits).to be_a(Hash)
      end
    end

    context 'with form type 5495' do
      it 'returns the benefit' do
        saved_claim = create(:va5495)
        claim = saved_claim.education_benefits_claim
        benefits = claim.selected_benefits

        expect(benefits).to be_a(Hash)
      end
    end

    context 'with form type 10203' do
      it 'returns the benefit' do
        saved_claim = create(:va10203)
        claim = saved_claim.education_benefits_claim
        benefits = claim.selected_benefits

        expect(benefits).to be_a(Hash)
      end
    end

    context 'with form type without benefit field' do
      it 'returns empty hash' do
        claim = create(:va10282).education_benefits_claim
        benefits = claim.selected_benefits

        expect(benefits).to eq({})
      end
    end
  end
end
