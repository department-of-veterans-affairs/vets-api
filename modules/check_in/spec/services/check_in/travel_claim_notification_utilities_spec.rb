# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::TravelClaimNotificationUtilities do
  before { allow(StatsD).to receive(:increment) }

  describe '.determine_facility_type_from_template' do
    it 'returns "oh" for OH template IDs and nil' do
      oh_templates = [
        'oh-failure-template-id',
        CheckIn::Constants::OH_ERROR_TEMPLATE_ID,
        CheckIn::Constants::OH_TIMEOUT_TEMPLATE_ID,
        CheckIn::Constants::OH_SUCCESS_TEMPLATE_ID,
        CheckIn::Constants::OH_DUPLICATE_TEMPLATE_ID,
        nil # OH_FAILURE_TEMPLATE_ID is nil in test settings
      ]

      oh_templates.each do |template|
        expect(described_class.determine_facility_type_from_template(template)).to eq('oh')
      end
    end

    it 'returns "cie" for CIE templates and unknown templates' do
      cie_templates = [
        'cie-failure-template-id',
        CheckIn::Constants::CIE_ERROR_TEMPLATE_ID,
        CheckIn::Constants::CIE_TIMEOUT_TEMPLATE_ID,
        'some-random-template-id',
        ''
      ]

      cie_templates.each do |template|
        expect(described_class.determine_facility_type_from_template(template)).to eq('cie')
      end
    end
  end

  describe '.failure_template?' do
    it 'returns true for failure templates' do
      failure_templates = [
        CheckIn::Constants::CIE_TIMEOUT_TEMPLATE_ID,
        CheckIn::Constants::CIE_ERROR_TEMPLATE_ID,
        'oh-failure-template-id',
        'cie-failure-template-id',
        nil # nil is in FAILED_CLAIM_TEMPLATE_IDS
      ]

      failure_templates.each do |template|
        expect(described_class.failure_template?(template)).to be true
      end
    end

    it 'returns false for non-failure templates' do
      ['success-template-id', ''].each do |template|
        expect(described_class.failure_template?(template)).to be false
      end
    end
  end

  describe '.increment_silent_failure_metrics' do
    it 'increments metrics with correct tags for failure templates' do
      described_class.increment_silent_failure_metrics('oh-failure-template-id', 'oh')
      expect(StatsD).to have_received(:increment).with(
        CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
        tags: CheckIn::Constants::STATSD_OH_SILENT_FAILURE_TAGS
      )

      described_class.increment_silent_failure_metrics('cie-failure-template-id', 'cie')
      expect(StatsD).to have_received(:increment).with(
        CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
        tags: CheckIn::Constants::STATSD_CIE_SILENT_FAILURE_TAGS
      )
    end

    it 'determines facility type when nil is passed and increments for nil template' do
      described_class.increment_silent_failure_metrics('oh-failure-template-id', nil)
      described_class.increment_silent_failure_metrics(nil, 'oh')

      expect(StatsD).to have_received(:increment).with(
        CheckIn::Constants::STATSD_NOTIFY_SILENT_FAILURE,
        tags: CheckIn::Constants::STATSD_OH_SILENT_FAILURE_TAGS
      ).twice
    end

    it 'does not increment metrics for non-failure templates' do
      described_class.increment_silent_failure_metrics('success-template-id', 'oh')
      expect(StatsD).not_to have_received(:increment)
    end
  end

  describe '.phone_last_four' do
    it 'extracts last four digits from various phone number formats' do
      phone_tests = {
        '5551234567' => '4567',
        '(555) 123-4567' => '4567',
        '555 123 4567' => '4567',
        '555-123.4567' => '4567',
        '+1-555-123-4567' => '4567',
        '123' => '123',
        '1234' => '1234'
      }

      phone_tests.each do |input, expected|
        expect(described_class.extract_phone_last_four(input)).to eq(expected)
      end
    end

    it 'handles invalid input appropriately' do
      expect(described_class.extract_phone_last_four(nil)).to eq('unknown')
      expect(described_class.extract_phone_last_four('')).to eq('unknown')
      expect(described_class.extract_phone_last_four('abc-def-ghij')).to eq('unknown')
    end
  end
end
