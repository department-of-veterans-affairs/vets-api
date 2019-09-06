# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::EducationBenefitsClaimsController, type: :controller do
  it_should_behave_like 'a controller that deletes an InProgressForm', 'education_benefits_claim', 'va1990', '22-1990'

  describe '#create' do
    def parsed_body
      JSON.parse(response.body)
    end

    context 'with a 1995' do
      let(:valid1995s_as1995) { build(:va1995s).form }
      let(:valid1995) { build(:va1995).form }

      it 'correctly creates a 1995s submission' do
        post(:create, params: { education_benefits_claim: { form: valid1995s_as1995 }, form_type: '1995' })
        expect(parsed_body['data']['attributes']['form_type']).to eq('1995s')
      end

      it 'correctly creates a 1995 submission' do
        post(:create, params: { education_benefits_claim: { form: valid1995 }, form_type: '1995' })
        expect(parsed_body['data']['attributes']['form_type']).to eq('1995')
      end
    end
  end
end
