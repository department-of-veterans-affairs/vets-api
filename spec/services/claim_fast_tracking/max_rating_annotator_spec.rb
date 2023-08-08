# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimFastTracking::MaxRatingAnnotator do
  describe 'annotate_disabilities' do
    subject { described_class.annotate_disabilities(disabilities_response) }

    let(:disabilities_response) do
      DisabilityCompensation::ApiProvider::RatedDisabilitiesResponse.new(rated_disabilities:)
    end
    let(:rated_disabilities) do
      disabilities_data.map { |dis| DisabilityCompensation::ApiProvider::RatedDisability.new(**dis) }
    end

    context 'when a disabilities response contains tinnitus and other disabilities' do
      let(:disabilities_data) do
        [
          { name: 'Hypertension', diagnostic_code: 7101, rating_percentage: 20 },
          { name: 'Tinnitus', diagnostic_code: 6260, rating_percentage: 10 },
          { name: 'Vertigo', diagnostic_code: 6204, rating_percentage: 30 }
        ]
      end

      it 'mutates just the tinnitus disability with a max rating' do
        subject
        max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
        expect(max_ratings).to eq([nil, 10, nil])
      end
    end
  end
end
