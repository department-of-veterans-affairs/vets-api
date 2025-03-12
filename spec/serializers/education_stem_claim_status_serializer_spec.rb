# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationStemClaimStatusSerializer do
  context 'with unprocessed claim' do
    subject { serialize(education_benefits_claim, serializer_class: described_class) }

    let(:education_benefits_claim) { create(:education_benefits_claim_10203, :with_stem) }
    let(:data) { JSON.parse(subject)['data'] }
    let(:attributes) { data['attributes'] }

    it 'includes id' do
      expect(data['id']).to eq(education_benefits_claim.id.to_s)
    end

    it 'includes automated_denial' do
      expect(attributes['automated_denial']).to be(false)
    end

    it 'includes remaining_entitlement' do
      expect(attributes['remaining_entitlement']).to be_nil
    end

    it 'includes submitted_at' do
      expect(attributes['submitted_at']).not_to be_nil
    end

    it 'includes denied_at' do
      expect(attributes['denied_at']).to be_nil
    end

    it 'includes is_enrolled_stem' do
      expect(attributes['is_enrolled_stem']).to eq(education_benefits_claim.saved_claim.parsed_form['isEnrolledStem'])
    end

    it 'includes is_pursuing_teaching_cert' do
      expect(attributes['is_pursuing_teaching_cert']).to eq(
        education_benefits_claim.saved_claim.parsed_form['isPursuingTeachingCert']
      )
    end

    it 'includes benefit_left' do
      expect(attributes['benefit_left']).to eq(education_benefits_claim.saved_claim.parsed_form['benefitLeft'])
    end

    it 'does not include any extra attributes' do
      expect(attributes.keys).to eq(%w[confirmation_number
                                       is_enrolled_stem
                                       is_pursuing_teaching_cert
                                       benefit_left
                                       remaining_entitlement
                                       automated_denial
                                       denied_at
                                       submitted_at])
    end
  end

  context 'with denied claim' do
    subject { serialize(education_benefits_claim, serializer_class: described_class) }

    let(:education_benefits_claim) { create(:education_benefits_claim_10203, :with_denied_stem) }
    let(:data) { JSON.parse(subject)['data'] }
    let(:attributes) { data['attributes'] }

    it 'includes automated_denial' do
      expect(attributes['automated_denial']).to be(true)
    end

    it 'includes remaining_entitlement' do
      expect(attributes['remaining_entitlement']).to eq(181)
    end

    it 'includes denied_at' do
      expect(attributes['denied_at']).not_to be_nil
    end
  end
end
