# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/rated_disabilities/lighthouse_rated_disabilities_provider'

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
        { name: 'Tinnitus', diagnostic_code: 6260, rating_percentage: 10 },
        { name: 'Hypertension', diagnostic_code: 7101, rating_percentage: 20 },
        { name: 'Vertigo', diagnostic_code: 6204, rating_percentage: 30 }
      ]
    end

    context 'when a disabilities response does not contains rating any disability' do
      it 'mutates none of the disabilities with a max rating' do
        VCR.use_cassette('disability_max_ratings/max_ratings_none') do
          subject
          max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
          expect(max_ratings).to eq([nil, nil, nil])
        end
      end
    end

    context 'when a disabilities response contains rating for a single disability' do
      it 'mutates just the rated disability with a max rating' do
        VCR.use_cassette('disability_max_ratings/max_ratings') do
          subject
          max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
          expect(max_ratings).to eq([10, nil, nil])
        end
      end
    end

    context 'when a disabilities response contains rating for a multiple disabilities' do
      it 'mutates just the rated disabilities with a max rating' do
        VCR.use_cassette('disability_max_ratings/max_ratings_multiple') do
          subject
          max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
          expect(max_ratings).to eq([10, 60, nil])
        end
      end
    end

    context 'when a disabilities response contains unexpected data' do
      context 'disabilities response contains nil for rated_disabilities' do
        let(:rated_disabilities) { nil }

        it 'mutates only the valid disability with a max rating' do
          subject
          max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
          expect(max_ratings).to eq([])
        end
      end

      context 'disabilities response contains a nil entry in rated_disabilities array' do
        let(:disabilities_response) do
          resp = DisabilityCompensation::ApiProvider::RatedDisabilitiesResponse.new
          resp.rated_disabilities = nil
          resp
        end

        it 'no disabilities to mutate' do
          VCR.use_cassette('disability_max_ratings/max_ratings') do
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
          VCR.use_cassette('disability_max_ratings/max_ratings') do
            subject
            max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
            expect(max_ratings).to eq([10, nil, nil])
          end
        end
      end
    end

    context 'when max rating endpoint fails' do
      it 'mutates none of the disabilities with a max rating' do
        VCR.use_cassette('disability_max_ratings/max_ratings_failure') do
          subject
          max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
          expect(max_ratings).to eq([nil, nil, nil])
        end
      end
    end
  end

  describe 'log_hyphenated_diagnostic_codes' do
    subject { described_class.log_hyphenated_diagnostic_codes(rated_disabilities) }

    before { allow(StatsD).to receive(:increment) }

    let(:rated_disabilities) do
      disabilities_data.map { |dis| DisabilityCompensation::ApiProvider::RatedDisability.new(**dis) }
    end
    let(:disabilities_data) do
      [
        { name: 'Tinnitus', diagnostic_code: 6260, rating_percentage: 10 },
        { name: 'Pancreatitis, chronic', diagnostic_code: 7347, rating_percentage: 30 },
        { name: 'Postop tonsillectomy', diagnostic_code: 6516, hyphenated_diagnostic_code: 6599, rating_percentage: 30 }
      ]
    end

    it 'increments StatsD metrics for each rated disability' do
      subject

      expect(StatsD).to have_received(:increment).with(
        'api.max_cfi.rated_disability',
        tags: [
          'diagnostic_code:6260',
          'diagnostic_code_type:primary_max_rating',
          'hyphenated_diagnostic_code:'
        ]
      )

      expect(StatsD).to have_received(:increment).with(
        'api.max_cfi.rated_disability',
        tags: [
          'diagnostic_code:7347',
          'diagnostic_code_type:digestive_system',
          'hyphenated_diagnostic_code:'
        ]
      )

      expect(StatsD).to have_received(:increment).with(
        'api.max_cfi.rated_disability',
        tags: [
          'diagnostic_code:6516',
          'diagnostic_code_type:analogous_code',
          'hyphenated_diagnostic_code:6599'
        ]
      )
    end
  end

  describe 'diagnostic_code_type' do
    subject { described_class.diagnostic_code_type(rated_disability) }

    let(:rated_disability) do
      DisabilityCompensation::ApiProvider::RatedDisability.new(diagnostic_code:, hyphenated_diagnostic_code:)
    end
    let(:hyphenated_diagnostic_code) { nil }

    context 'when diagnostic code is nil' do
      let(:diagnostic_code) { nil }

      it { is_expected.to eq(:missing_diagnostic_code) }
    end

    context 'when diagnostic code is in the digestive system range' do
      let(:diagnostic_code) { 7329 }

      it { is_expected.to eq(:digestive_system) }
    end

    context 'when diagnostic code is in the infectious disease range' do
      let(:diagnostic_code) { 6354 }

      it { is_expected.to eq(:infectious_disease) }
    end

    context 'when diagnostic code is for an unlisted condition requiring an analogous code' do
      let(:hyphenated_diagnostic_code) { 6599 }
      let(:diagnostic_code) { 6516 }

      it { is_expected.to eq(:analogous_code) }
    end

    context 'when diagnostic code does not invoke any hyphenated logic' do
      let(:diagnostic_code) { 6260 }

      it { is_expected.to eq(:primary_max_rating) }
    end
  end

  describe 'eligible_for_request?' do
    subject { described_class.eligible_for_request?(rated_disability) }

    let(:rated_disability) { DisabilityCompensation::ApiProvider::RatedDisability.new(**rd_hash) }

    context 'when rated disability is for an infectious disease' do
      let(:rd_hash) { { diagnostic_code: 6354 } }

      it { is_expected.to be_falsey }
    end

    context 'when rated disability is for an excluded digestive condition' do
      let(:rd_hash) { { diagnostic_code: 7346 } }

      it { is_expected.to be_falsey }
    end

    context 'when rated disability is for a non-excluded digestive condition' do
      let(:rd_hash) { { diagnostic_code: 7347 } }

      it { is_expected.to be_truthy }
    end
  end

  describe 'get_ratings' do
    let(:diagnostic_codes) { [6260, 7347, 6516] }

    it 'calls the DisabilityMaxRating::Client to fetch multiple max ratings' do
      VCR.use_cassette('disability_max_ratings/max_ratings_multiple') do
        diagnostic_codes = [6260, 7101, 6204]
        result = described_class.send(:get_ratings, diagnostic_codes)
        expect(result).to eq([
                               { 'diagnostic_code' => 7101, 'max_rating' => 60.0 },
                               { 'diagnostic_code' => 6260, 'max_rating' => 10.0 }
                             ])
      end
    end

    it 'calls the DisabilityMaxRating::Client to fetch single max ratings' do
      VCR.use_cassette('disability_max_ratings/max_ratings') do
        diagnostic_codes = [6260]
        result = described_class.send(:get_ratings, diagnostic_codes)
        expect(result).to eq([{ 'diagnostic_code' => 6260, 'max_rating' => 10.0 }])
      end
    end

    it 'returns an empty array when no ratings are found' do
      VCR.use_cassette('disability_max_ratings/max_ratings_none') do
        result = described_class.send(:get_ratings, diagnostic_codes)
        expect(result).to eq([])
      end
    end

    it 'logs an error when the DisabilityMaxRating client raises a ClientError' do
      VCR.use_cassette('disability_max_ratings/max_ratings_failure') do
        expect(Rails.logger).to receive(:error).with(
          'Get Max Ratings Failed  the server responded with status 500.',
          hash_including(:backtrace)
        )

        result = described_class.send(:get_ratings, diagnostic_codes)
        expect(result).to be_nil
      end
    end

    context 'when the API times out' do
      before do
        allow_any_instance_of(DisabilityMaxRatings::Client).to receive(:post_for_max_ratings)
          .and_raise(Faraday::TimeoutError)
      end

      it 'logs the timeout error and returns nil' do
        expect(Rails.logger).to receive(:error).with(
          'Get Max Ratings Failed: Request timed out.'
        )

        result = described_class.send(:get_ratings, diagnostic_codes)
        expect(result).to be_nil
      end
    end
  end
end
