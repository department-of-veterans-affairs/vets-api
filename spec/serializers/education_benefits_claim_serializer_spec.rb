# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationBenefitsClaimSerializer, type: :serializer do
  let(:education_benefits_claim) { create(:education_benefits_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  subject { serialize(education_benefits_claim) }

  it 'should include id' do
    expect(data['id']).to eq(education_benefits_claim.id.to_s)
  end

  %w[form regional_office confirmation_number].each do |attr|
    it "should include #{attr}" do
      expect(attributes[attr]).to eq(education_benefits_claim.public_send(attr))
    end
  end

  it "shouldn't include any extra attributes" do
    expect(attributes.keys).to eq(%w[form regional_office confirmation_number])
  end
end
