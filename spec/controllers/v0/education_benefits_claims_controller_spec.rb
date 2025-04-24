# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::EducationBenefitsClaimsController, type: :controller do
  it_behaves_like 'a controller that deletes an InProgressForm', 'education_benefits_claim', 'va1990', '22-1990'

  context 'with a user' do
    let(:user) { create(:user, :loa3, :with_terms_of_use_agreement) }

    it 'returns zero results for a user without submissions' do
      sign_in_as(user)
      create(:va10203, education_benefits_claim: create(:education_benefits_claim))
        .after_submit(create(:user, :loa3, uuid: SecureRandom.uuid, idme_uuid: nil))

      get(:stem_claim_status)

      body = JSON.parse response.body
      expect(response.content_type).to eq('application/json; charset=utf-8')
      expect(body['data']).to eq([])
    end

    it 'returns results for a user with submissions' do
      sign_in_as(user)
      va10203 = create(:va10203, education_benefits_claim: create(:education_benefits_claim))
      va10203.after_submit(user)

      get(:stem_claim_status)

      body = JSON.parse response.body
      expect(response.content_type).to eq('application/json; charset=utf-8')
      expect(body['data'].length).to eq(1)
    end
  end

  context 'without a user' do
    it 'returns zero results' do
      get(:stem_claim_status)
      body = JSON.parse response.body
      expect(response.content_type).to eq('application/json; charset=utf-8')
      expect(body['data']).to eq([])
    end
  end
end
