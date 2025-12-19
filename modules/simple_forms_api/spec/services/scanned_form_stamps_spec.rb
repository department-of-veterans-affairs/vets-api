# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::ScannedFormStamps do
  let(:timestamp) { Time.zone.parse('2025-11-07 18:35:00 UTC') }

  describe '.stamps?' do
    it 'returns true for forms with stamps' do
      expect(described_class.stamps?('21-0779')).to be true
      expect(described_class.stamps?('21-0304')).to be true
    end

    it 'returns false for forms without stamps' do
      expect(described_class.stamps?('21-4192')).to be false
      expect(described_class.stamps?('21-509')).to be false
      expect(described_class.stamps?('99-9999')).to be false
    end
  end

  describe '#desired_stamps' do
    it 'returns empty array' do
      stamp_config = described_class.new('21-0779')
      expect(stamp_config.desired_stamps).to eq([])
    end
  end

  describe '#submission_date_stamps' do
    it 'returns two stamps with correct structure' do
      stamp_config = described_class.new('21-0779')
      stamps = stamp_config.submission_date_stamps(timestamp)

      expect(stamps.length).to eq(2)

      expect(stamps[0]).to eq(
        coords: [460, 710],
        text: 'Application Submitted:',
        page: 0,
        font_size: 12
      )

      expect(stamps[1]).to eq(
        coords: [460, 690],
        text: '18:35 UTC 11/07/25',
        page: 0,
        font_size: 12
      )
    end

    it 'stamps on page 1 for form 21-0304' do
      stamp_config = described_class.new('21-0304')
      stamps = stamp_config.submission_date_stamps(timestamp)

      expect(stamps[0][:page]).to eq(1)
      expect(stamps[1][:page]).to eq(1)
    end

    it 'formats timestamp correctly' do
      custom_time = Time.zone.parse('2024-12-25 10:30:45 UTC')
      stamp_config = described_class.new('21-0779')
      stamps = stamp_config.submission_date_stamps(custom_time)

      expect(stamps[1][:text]).to eq('10:30 UTC 12/25/24')
    end
  end

  describe 'constants validation' do
    it 'has correct configuration' do
      expect(described_class::TIMESTAMP_LINE_1_COORDS).to eq([460, 710])
      expect(described_class::TIMESTAMP_LINE_2_COORDS).to eq([460, 690])
      expect(described_class::TIMESTAMP_FONT_SIZE).to eq(12)
      expect(described_class::STAMP_PAGE_OVERRIDES).to eq({ '21-0304' => 1 })
      expect(described_class::STAMP_COORDINATE_OVERRIDES).to eq({
                                                                  '21-0304' => {
                                                                    line_one: [460, 660],
                                                                    line_two: [460, 640]
                                                                  }
                                                                })
    end
  end
end
