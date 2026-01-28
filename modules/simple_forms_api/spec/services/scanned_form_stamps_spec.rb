# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::ScannedFormStamps do
  let(:timestamp) { Time.zone.parse('2025-11-07 18:35:00 UTC') }

  describe '.stamps?' do
    context 'with forms that have stamps' do
      described_class::FORMS_WITH_STAMPS.each do |form_number|
        it "returns true for #{form_number}" do
          expect(described_class.stamps?(form_number)).to be true
        end
      end
    end

    context 'with forms that do not have stamps' do
      %w[21-4192 21-509 99-9999].each do |form_number|
        it "returns false for #{form_number}" do
          expect(described_class.stamps?(form_number)).to be false
        end
      end
    end

    it 'returns false for nil' do
      expect(described_class.stamps?(nil)).to be false
    end
  end

  describe '#desired_stamps' do
    it 'returns an empty array' do
      stamp_config = described_class.new('21-0779')
      expect(stamp_config.desired_stamps).to eq([])
    end
  end

  describe '#submission_date_stamps' do
    context 'with a standard form (no overrides)' do
      subject(:stamps) { described_class.new('21-0779').submission_date_stamps(timestamp) }

      it 'returns two stamps' do
        expect(stamps.length).to eq(2)
      end

      it 'includes the submission label stamp' do
        expect(stamps[0]).to include(
          coords: described_class::TIMESTAMP_LINE_1_COORDS,
          text: 'Application Submitted:',
          page: 0,
          font_size: described_class::TIMESTAMP_FONT_SIZE
        )
      end

      it 'includes the formatted timestamp stamp' do
        expect(stamps[1]).to include(
          coords: described_class::TIMESTAMP_LINE_2_COORDS,
          text: '18:35 UTC 11/07/25',
          page: 0,
          font_size: described_class::TIMESTAMP_FONT_SIZE
        )
      end
    end

    context 'with form 21-0304 (page and coordinate overrides)' do
      subject(:stamps) { described_class.new('21-0304').submission_date_stamps(timestamp) }

      it 'stamps on page 1' do
        expect(stamps.map { |s| s[:page] }).to all(eq(1))
      end

      it 'uses custom coordinates for line one' do
        expect(stamps[0][:coords]).to eq([460, 660])
      end

      it 'uses custom coordinates for line two' do
        expect(stamps[1][:coords]).to eq([460, 640])
      end
    end

    context 'with form 21P-535 (page override only)' do
      subject(:stamps) { described_class.new('21P-535').submission_date_stamps(timestamp) }

      it 'stamps on the third page (page index 2)' do
        expect(stamps.map { |s| s[:page] }).to all(eq(2))
      end

      it 'uses default coordinates' do
        expect(stamps[0][:coords]).to eq(described_class::TIMESTAMP_LINE_1_COORDS)
        expect(stamps[1][:coords]).to eq(described_class::TIMESTAMP_LINE_2_COORDS)
      end
    end

    describe 'timestamp formatting' do
      it 'formats the timestamp in UTC with HH:MM ZZZ MM/DD/YY format' do
        custom_time = Time.zone.parse('2024-12-25 10:30:45 UTC')
        stamps = described_class.new('21-0779').submission_date_stamps(custom_time)

        expect(stamps[1][:text]).to eq('10:30 UTC 12/25/24')
      end

      it 'converts non-UTC times to UTC' do
        eastern_time = Time.zone.parse('2024-12-25 10:30:45 EST')
        stamps = described_class.new('21-0779').submission_date_stamps(eastern_time)

        expect(stamps[1][:text]).to eq('15:30 UTC 12/25/24')
      end
    end
  end

  describe 'configuration consistency' do
    it 'has page overrides only for forms in FORMS_WITH_STAMPS' do
      override_forms = described_class::STAMP_PAGE_OVERRIDES.keys
      expect(override_forms).to all(be_in(described_class::FORMS_WITH_STAMPS))
    end

    it 'has coordinate overrides only for forms in FORMS_WITH_STAMPS' do
      override_forms = described_class::STAMP_COORDINATE_OVERRIDES.keys
      expect(override_forms).to all(be_in(described_class::FORMS_WITH_STAMPS))
    end
  end
end
