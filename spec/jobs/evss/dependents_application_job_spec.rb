# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DependentsApplicationJob do
  describe '#perform' do
    let(:user) { create(:evss_user) }

    it 'submits to the 686 api' do
      VCR.use_cassette(
        'evss/dependents/all',
        VCR::MATCH_EVERYTHING
      ) do
        dependents_application = create(:dependents_application, user: user)
        described_class.drain

        dependents_application = DependentsApplication.find(dependents_application.id)
        expect(dependents_application.state).to eq('success')
        expect(dependents_application.parsed_response).to eq(
          'submit686Response' => { 'confirmationNumber' => '600142505' }
        )
      end
    end
  end
end
