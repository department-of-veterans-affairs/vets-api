# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::ScannedFormStamps do
  let(:timestamp) { Time.zone.parse('2025-11-07 18:35:00 UTC') }

  FORMS_WITH_STAMPS = %w[
    21-0779
    21-8940
    21P-530a
    21P-8049
    21-2680
    21-674b
    21-8951-2
    21-0788
    21-4193
    21P-4718a
    21-4140
    21-0304
  ].freeze

  FORMS_WITHOUT_STAMPS = %w[
    21-4192
    21-509
    21P-0516-1
    21P-0517-1
    21P-0518-1
    21P-0519C-1
    21P-0519S-1
    21P-4706c
    21-8960
    21-651
    21P-4185
  ].freeze

  FORMS_WITH_PAGE_1_STAMPS = ['21-0304'].freeze

  describe '.has_stamps?' do
    context 'for forms that need stamps' do
      FORMS_WITH_STAMPS.each do |form_number|
        it "returns true for #{form_number}" do
          expect(described_class.has_stamps?(form_number)).to be true
        end
      end
    end

    context 'for forms that do not need stamps' do
      FORMS_WITHOUT_STAMPS.each do |form_number|
        it "returns false for #{form_number}" do
          expect(described_class.has_stamps?(form_number)).to be false
        end
      end
    end

    context 'for unknown forms' do
      it 'returns false for non-existent form' do
        expect(described_class.has_stamps?('99-9999')).to be false
      end
    end
  end

  describe '#desired_stamps' do
    it 'returns an empty array for all forms' do
      stamp_config = described_class.new('21-0779')
      expect(stamp_config.desired_stamps).to eq([])
    end
  end

  describe '#submission_date_stamps' do
    context 'for forms with stamps' do
      FORMS_WITH_STAMPS.each do |form_number|
        it "returns stamps for #{form_number}" do
          stamp_config = described_class.new(form_number)
          stamps = stamp_config.submission_date_stamps(timestamp)

          expect(stamps).to be_an(Array)
          expect(stamps).not_to be_empty

          expect(stamps).to all(include(
                                  coords: an_instance_of(Array),
                                  text: an_instance_of(String),
                                  page: an_instance_of(Integer),
                                  font_size: an_instance_of(Integer)
                                ))
        end
      end
    end

    context 'for forms with stamps on page 1 (second page)' do
      FORMS_WITH_PAGE_1_STAMPS.each do |form_number|
        it "returns stamps on page 1 for #{form_number}" do
          stamp_config = described_class.new(form_number)
          stamps = stamp_config.submission_date_stamps(timestamp)

          expect(stamps).not_to be_empty
          expect(stamps.first[:page]).to eq(1)
        end
      end
    end

    context 'for forms without stamp configuration' do
      FORMS_WITHOUT_STAMPS.each do |form_number|
        it "returns an empty array for #{form_number}" do
          stamp_config = described_class.new(form_number)
          stamps = stamp_config.submission_date_stamps(timestamp)

          expect(stamps).to eq([])
        end
      end

      it 'returns an empty array for unknown form' do
        stamp_config = described_class.new('99-9999')
        stamps = stamp_config.submission_date_stamps(timestamp)

        expect(stamps).to eq([])
      end
    end

    context 'timestamp formatting' do
      it 'formats timestamp correctly' do
        stamp_config = described_class.new('21-0779')
        stamps = stamp_config.submission_date_stamps(timestamp)

        # Verify timestamp is formatted and included in the stamps
        expect(stamps.any? { |stamp| stamp[:text].match?(/\d{2}:\d{2}/) }).to be true
      end

      it 'uses UTC timezone' do
        stamp_config = described_class.new('21-0779')
        stamps = stamp_config.submission_date_stamps(timestamp)

        # Check that at least one stamp contains a formatted timestamp
        timestamp_stamp = stamps.find { |stamp| stamp[:text].match?(/\d{2}:\d{2}/) }
        expect(timestamp_stamp[:text]).to include('UTC')
      end
    end
  end

  describe 'stamp structure validation' do
    let(:stamp_config) { described_class.new('21-0779') }
    let(:stamps) { stamp_config.submission_date_stamps(timestamp) }

    it 'returns stamps with required keys' do
      stamps.each do |stamp|
        expect(stamp.keys).to include(:coords, :text, :page, :font_size)
      end
    end

    it 'has coords as a two-element array' do
      stamps.each do |stamp|
        expect(stamp[:coords]).to be_an(Array)
        expect(stamp[:coords].length).to eq(2)
        expect(stamp[:coords]).to all(be_a(Numeric))
      end
    end

    it 'has text as a non-empty string' do
      stamps.each do |stamp|
        expect(stamp[:text]).to be_a(String)
        expect(stamp[:text]).not_to be_empty
      end
    end

    it 'has page as a non-negative integer' do
      stamps.each do |stamp|
        expect(stamp[:page]).to be_an(Integer)
        expect(stamp[:page]).to be >= 0
      end
    end

    it 'has font_size as a positive integer' do
      stamps.each do |stamp|
        expect(stamp[:font_size]).to be_an(Integer)
        expect(stamp[:font_size]).to be.positive?
      end
    end
  end

  describe 'configuration consistency' do
    it 'ensures all forms with stamps are in STAMP_CONFIGS' do
      FORMS_WITH_STAMPS.each do |form_number|
        expect(described_class::STAMP_CONFIGS).to have_key(form_number),
                                                  "#{form_number} should be in STAMP_CONFIGS"
      end
    end

    it 'ensures no forms without stamps are in STAMP_CONFIGS' do
      FORMS_WITHOUT_STAMPS.each do |form_number|
        expect(described_class::STAMP_CONFIGS).not_to have_key(form_number),
                                                      "#{form_number} should NOT be in STAMP_CONFIGS"
      end
    end
  end
end
