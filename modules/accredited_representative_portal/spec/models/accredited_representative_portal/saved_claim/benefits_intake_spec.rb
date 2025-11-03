# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::SavedClaim::BenefitsIntake, type: :model do
  subject(:claim) do
    form = {}.to_json
    described_class::DependencyClaim.new(form:)
  end

  before do
    allow(VetsJsonSchema::SCHEMAS).to(
      receive(:[]).and_return({})
    )
  end

  describe 'form_id' do
    context 'when set automatically' do
      it 'is set validly' do
        expect(claim.form_id).to eq(
          '21-686C_BENEFITS-INTAKE'
        )

        claim.valid?
        errors = claim.errors.details[:form_id]
        expect(errors).to eq([])
      end
    end

    context 'when reset invalidly' do
      before do
        claim.form_id = 'INVALID'
      end

      it 'raises `ActiveModel::StrictValidationFailed` when validated' do
        expect { claim.valid? }.to raise_error(
          ActiveModel::StrictValidationFailed,
          'Form is not included in the list'
        )
      end
    end
  end

  describe 'form_attachment' do
    context 'without setting a `form_attachment`' do
      it 'is invalid when validating' do
        claim.valid?
        errors = claim.errors.details[:form_attachment]
        expect(errors).to eq([{ error: :blank }])
      end
    end

    context 'with setting a `form_attachment`' do
      before do
        claim.form_attachment = PersistentAttachments::VAForm.new
      end

      it 'is valid when validating' do
        claim.valid?
        errors = claim.errors.details[:form_attachment]
        expect(errors).to eq([])
      end
    end
  end

  describe 'constants' do
    it 'has BUSINESS_LINE defined correctly' do
      expect(claim.class::BUSINESS_LINE).to eq(
        'CMP'
      )
    end

    it 'has PROPER_FORM_ID defined correctly' do
      expect(claim.class::PROPER_FORM_ID).to eq(
        '21-686c'
      )
    end

    it 'has FORM_ID defined correctly' do
      expect(claim.class::FORM_ID).to eq(
        '21-686C_BENEFITS-INTAKE'
      )
    end
  end

  describe '#pending_submission_attempt_stale?' do
    let(:saved_claim) { create(:saved_claim_benefits_intake) }

    before do
      # This removes: SHRINE WARNING: Error occurred when attempting to extract image dimensions:
      # #<FastImage::UnknownImageType: FastImage::UnknownImageType>
      allow(FastImage).to receive(:size).and_wrap_original do |original, file|
        if file.respond_to?(:path) && file.path.end_with?('.pdf')
          nil
        else
          original.call(file)
        end
      end
    end

    context 'latest attempt was successful' do
      it 'returns false' do
        saved_claim.latest_submission_attempt.update(aasm_state: 'vbms')
        Timecop.freeze(10.days.from_now) do
          expect(saved_claim.pending_submission_attempt_stale?).to be false
        end
      end
    end

    context 'latest pending attempt is under 10 days ago' do
      it 'returns false' do
        expect(saved_claim.pending_submission_attempt_stale?).to be false
      end
    end

    context 'latest pending attempt was 10 days ago' do
      it 'returns true' do
        saved_claim.save
        Timecop.freeze(10.days.from_now) do
          expect(saved_claim.pending_submission_attempt_stale?).to be true
        end
      end
    end
  end
end
