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
end
