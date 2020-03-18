# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA1995s do
  let(:instance) { FactoryBot.build(:va1995s) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-1995S')

  describe '#in_progress_form_id' do
    it 'returns 22-1995' do
      form = create(:va1995s)
      expect(form.in_progress_form_id).to eq('22-1995')
    end
  end
end
