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
    let(:disabilities_data) do
      [
        { name: 'Hypertension', diagnostic_code: 7101, rating_percentage: 20 },
        { name: 'Tinnitus', diagnostic_code: 6260, rating_percentage: 10 },
        { name: 'Vertigo', diagnostic_code: 6204, rating_percentage: 30 }
      ]
    end

    context 'with disability_526_maximum_rating_api disabled' do
      before { Flipper.disable(:disability_526_maximum_rating_api) }

      it 'mutates just the tinnitus disability with hardcoded max rating' do
        subject
        max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
        expect(max_ratings).to eq([nil, 10, nil])
      end
    end

    context 'with disability_526_maximum_rating_api enabled' do
      before { Flipper.enable(:disability_526_maximum_rating_api) }
      after { Flipper.disable(:disability_526_maximum_rating_api) }

      context 'when a disabilities response contains rating for a disability' do
        it 'mutates just the rated disability with a max rating' do
          VCR.use_cassette('virtual_regional_office/max_ratings') do
            subject
            max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
            expect(max_ratings).to eq([nil, 10, nil])
          end
        end
      end

      context 'when a disabilities response does not contains rating any disability' do
        let(:disabilities_data) do
          [
            { name: 'Hypertension', diagnostic_code: 7101, rating_percentage: 20 },
            { name: 'Vertigo', diagnostic_code: 6204, rating_percentage: 30 }
          ]
        end

        it 'mutates none of the disabilities with a max rating' do
          VCR.use_cassette('virtual_regional_office/max_ratings') do
            subject
            max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
            expect(max_ratings).to eq([nil, nil])
          end
        end
      end

      context 'when a disabilities response contains unexpected data' do
        context 'disabilities response contains nil for rated_disabilities' do
          let(:rated_disabilities) { nil }

          it 'mutates only the valid disability with a max rating' do
            VCR.use_cassette('virtual_regional_office/max_ratings') do
              subject
              max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
              expect(max_ratings).to eq([])
            end
          end
        end

        context 'disabilities response contains a nil entry in rated_disabilities array' do
          let(:disabilities_response) do
            resp = DisabilityCompensation::ApiProvider::RatedDisabilitiesResponse.new
            resp.rated_disabilities = nil
            resp
          end

          it 'no disabilities to mutate' do
            VCR.use_cassette('virtual_regional_office/max_ratings') do
              subject
              max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
              expect(max_ratings).to eq([])
            end
          end
        end

        context 'disabilities response contains a rated disability with a nil or non-integer diagnostic_code' do
          let(:disabilities_data) do
            [
              { name: 'Tinnitus', diagnostic_code: 6260, rating_percentage: 10 },
              { name: 'Hypertension', rating_percentage: 20 }, # missing diagnostic_code,
              { name: 'Vertigo', diagnostic_code: nil, rating_percentage: 30 } # nil diagnostic_code
            ]
          end

          it 'mutates only the valid disability with a max rating' do
            VCR.use_cassette('virtual_regional_office/max_ratings') do
              subject
              max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
              expect(max_ratings).to eq([10, nil, nil])
            end
          end
        end
      end

      context 'when max rating VRO endpoint fails' do
        it 'mutates none of the disabilities with a max rating' do
          VCR.use_cassette('virtual_regional_office/max_ratings_failure') do
            subject
            max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
            expect(max_ratings).to eq([nil, nil, nil])
          end
        end
      end
    end
  end
end
