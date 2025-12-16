# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationBenefitsClaimSerializer do
  subject { serialize(education_benefits_claim) }

  let(:education_benefits_claim) { create(:education_benefits_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes id' do
    expect(data['id']).to eq(education_benefits_claim.token)
  end

  %w[form regional_office confirmation_number].each do |attr|
    it "includes #{attr}" do
      expect(attributes[attr]).to eq(education_benefits_claim.public_send(attr))
    end
  end

  it 'does not include any extra attributes' do
    expect(attributes.keys).to eq(%w[form regional_office confirmation_number])
  end
end
