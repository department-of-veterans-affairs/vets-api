# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DependentsApplicationJob do
  describe '#perform' do
    let(:user) { create(:evss_user) }

    it 'submits to the 686 api' do
      VCR.use_cassette(
        'evss/dependents/all',
        record: :once
      ) do
        dependents_application = create(:dependents_application, user: user)
        described_class.drain
      end
    end
  end
end
