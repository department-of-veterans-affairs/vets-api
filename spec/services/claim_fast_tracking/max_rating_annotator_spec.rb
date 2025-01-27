# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/rated_disabilities/lighthouse_rated_disabilities_provider'

RSpec.describe ClaimFastTracking::MaxRatingAnnotator do
  describe 'annotate_disabilities' do
    subject { described_class.annotate_disabilities(disabilities_response, user) }

    let(:user) { create(:user, :loa3) }
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

    before do
      allow(Flipper).to receive(:enabled?).with(:disability_526_max_cfi_service_switch, user).and_return(false)
    end

    context 'when a disabilities response does not contains rating any disability' do
      it 'mutates none of the disabilities with a max rating' do
        VCR.use_cassette('virtual_regional_office/max_ratings_none') do
          subject
          max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
          expect(max_ratings).to eq([nil, nil, nil])
        end
      end
    end

    context 'when a disabilities response contains rating for a single disability' do
      it 'mutates just the rated disability with a max rating' do
        VCR.use_cassette('virtual_regional_office/max_ratings') do
          subject
          max_ratings = disabilities_response.rated_disabilities.map(&:maximum_rating_percentage)
          expect(max_ratings).to eq([10, nil, nil])
        end
      end
    end

    context 'when a disabilities response contains rating for a multiple disabilities' do
      it 'mutates just the rated disabilities with a max rating' do
        VCR.use_cassette('virtual_regional_office/max_ratings_multiple') do
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

  describe 'get ratings' do
    let(:diagnostic_codes) { [6260, 7347, 6516] }
    let(:user) { create(:user, :loa3) }

    context 'when the feature flag disability_526_max_cfi_service_switch is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:disability_526_max_cfi_service_switch, user).and_return(true)
      end

      it 'calls the DisabilityMaxRating::Client to fetch max ratings' do
        max_ratings_client = instance_double(DisabilityMaxRating::Client)
        response = double('response', body: { 'ratings' => [40, 50, 60] })

        allow(DisabilityMaxRating::Client).to receive(:new).and_return(max_ratings_client)
        allow(max_ratings_client)
          .to receive(:get_max_rating_for_diagnostic_codes)
          .with(diagnostic_codes)
          .and_return(response)

        result = described_class.send(:get_ratings, diagnostic_codes, user)
        expect(result).to eq([40, 50, 60])
      end

      it 'logs an error when the DisabilityMaxRating client raises a ClientError' do
        max_ratings_client = instance_double(DisabilityMaxRating::Client)
        allow(DisabilityMaxRating::Client).to receive(:new).and_return(max_ratings_client)
        allow(max_ratings_client).to receive(:get_max_rating_for_diagnostic_codes).and_raise(
          Common::Client::Errors::ClientError.new('Failed miserably')
        )

        expect(Rails.logger).to receive(:error).with(
          'Get Max Ratings Failed  Failed miserably.',
          hash_including(:backtrace)
        )

        result = described_class.send(:get_ratings, diagnostic_codes, user)
        expect(result).to be_nil
      end
    end

    context 'when the feature flag disability_526_max_cfi_service_switch is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:disability_526_max_cfi_service_switch, user).and_return(false)
      end

      it 'calls the VRO client to fetch max ratings' do
        vro_client = instance_double(VirtualRegionalOffice::Client)
        response = double('response', body: { 'ratings' => [10, 20, 30] })

        allow(VirtualRegionalOffice::Client).to receive(:new).and_return(vro_client)
        allow(vro_client).to receive(:get_max_rating_for_diagnostic_codes).with(diagnostic_codes).and_return(response)

        result = described_class.send(:get_ratings, diagnostic_codes, user)
        expect(result).to eq([10, 20, 30])
      end

      it 'logs an error when the VRO client raises a ClientError' do
        vro_client = instance_double(VirtualRegionalOffice::Client)
        allow(VirtualRegionalOffice::Client).to receive(:new).and_return(vro_client)
        allow(vro_client).to receive(:get_max_rating_for_diagnostic_codes).and_raise(
          Common::Client::Errors::ClientError.new('Miserably')
        )
        expect(Rails.logger).to receive(:error).with(
          'Get Max Ratings Failed  Miserably.',
          hash_including(:backtrace)
        )

        result = described_class.send(:get_ratings, diagnostic_codes, user)
        expect(result).to be_nil
      end
    end
  end
end
