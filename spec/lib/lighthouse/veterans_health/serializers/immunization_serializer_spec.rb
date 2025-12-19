# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/veterans_health/serializers/immunization_serializer'

RSpec.describe Lighthouse::VeteransHealth::Serializers::ImmunizationSerializer do
  describe '.extract_group_name' do
    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_vaccine_lighthouse_name_logging).and_return(true)
    end

    context 'when coding has VACCINE GROUP: prefix at start with space' do
      let(:vaccine_code) do
        {
          'text' => 'COVID-19 vaccine',
          'coding' => [
            { 'code' => '207', 'display' => 'COVID-19' },
            { 'display' => 'VACCINE GROUP: COVID-19' }
          ]
        }
      end

      it 'extracts the group name correctly' do
        expect(Rails.logger).to receive(:info).with(
          'Immunizations group_name processing',
          hash_including(
            coding_count: 2,
            vaccine_group_lengths: [9]
          )
        )

        result = described_class.extract_group_name(vaccine_code)
        expect(result).to eq('COVID-19')
      end

      context 'when logging is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_vaccine_lighthouse_name_logging).and_return(false)
        end

        it 'does not log' do
          expect(Rails.logger).not_to receive(:info).with('Immunizations group_name processing', anything)

          result = described_class.extract_group_name(vaccine_code)
          expect(result).to eq('COVID-19')
        end
      end
    end

    context 'when coding has VACCINE GROUP: prefix without space' do
      let(:vaccine_code) do
        {
          'text' => 'Influenza vaccine',
          'coding' => [
            { 'code' => '141', 'display' => 'Influenza seasonal' },
            { 'display' => 'VACCINE GROUP:INFLUENZA' }
          ]
        }
      end

      it 'extracts the group name correctly' do
        expect(Rails.logger).to receive(:info).with(
          'Immunizations group_name processing',
          hash_including(
            coding_count: 2,
            vaccine_group_lengths: [9]
          )
        )

        result = described_class.extract_group_name(vaccine_code)
        expect(result).to eq('INFLUENZA')
      end
    end

    context 'when coding has VACCINE GROUP: prefix with extra whitespace' do
      let(:vaccine_code) do
        {
          'text' => 'Hepatitis B vaccine',
          'coding' => [
            { 'code' => '45', 'display' => 'HEPATITIS B' },
            { 'display' => 'VACCINE GROUP:   HEPATITIS B' }
          ]
        }
      end

      it 'extracts the group name correctly after stripping whitespace' do
        expect(Rails.logger).to receive(:info).with(
          'Immunizations group_name processing',
          hash_including(
            coding_count: 2,
            vaccine_group_lengths: [14]
          )
        )

        result = described_class.extract_group_name(vaccine_code)
        expect(result).to eq('HEPATITIS B')
      end
    end

    context 'when VACCINE GROUP is in middle of text' do
      let(:vaccine_code) do
        {
          'text' => 'Tetanus vaccine',
          'coding' => [
            { 'code' => '35', 'display' => 'This is VACCINE GROUP: in middle' },
            { 'display' => 'TETANUS' }
          ]
        }
      end

      it 'falls back to CVX system if no prefix match' do
        expect(Rails.logger).to receive(:info).with(
          'Immunizations group_name processing',
          hash_including(
            coding_count: 2,
            vaccine_group_lengths: []
          )
        )

        result = described_class.extract_group_name(vaccine_code)
        expect(result).to eq('This is VACCINE GROUP: in middle')
      end
    end

    context 'when only one coding entry exists' do
      let(:vaccine_code) do
        {
          'text' => 'Polio vaccine',
          'coding' => [
            { 'code' => '10', 'system' => 'http://hl7.org/fhir/sid/cvx', 'display' => 'POLIO' }
          ]
        }
      end

      it 'falls back to index 0 display' do
        expect(Rails.logger).to receive(:info).with(
          'Immunizations group_name processing',
          hash_including(
            coding_count: 1,
            vaccine_group_lengths: []
          )
        )

        result = described_class.extract_group_name(vaccine_code)
        expect(result).to eq('POLIO')
      end
    end

    context 'when VACCINE GROUP: prefix has only whitespace after' do
      let(:vaccine_code) do
        {
          'text' => 'Unknown vaccine',
          'coding' => [
            { 'code' => '999', 'system' => 'http://hl7.org/fhir/sid/cvx', 'display' => 'UNKNOWN' },
            { 'display' => 'VACCINE GROUP:   ' }
          ]
        }
      end

      it 'falls back to CVX system display after stripping whitespace' do
        expect(Rails.logger).to receive(:info).with(
          'Immunizations group_name processing',
          hash_including(
            coding_count: 2,
            vaccine_group_lengths: [3]
          )
        )

        result = described_class.extract_group_name(vaccine_code)
        expect(result).to eq('UNKNOWN')
      end
    end

    context 'when VACCINE GROUP: prefix has nothing after' do
      let(:vaccine_code) do
        {
          'coding' => [
            { 'code' => '999', 'system' => 'http://hl7.org/fhir/sid/ndc', 'display' => 'Unknown vaccine' },
            { 'display' => 'VACCINE GROUP:' }
          ]
        }
      end

      it 'falls back to NDC system display for empty group name after stripping' do
        expect(Rails.logger).to receive(:info).with(
          'Immunizations group_name processing',
          hash_including(
            coding_count: 2,
            vaccine_group_lengths: [0]
          )
        )

        result = described_class.extract_group_name(vaccine_code)
        expect(result).to eq('Unknown vaccine')
      end
    end

    context 'when coding display is nil' do
      let(:vaccine_code) do
        {
          'text' => 'Varicella vaccine',
          'coding' => [
            { 'code' => '21', 'display' => nil },
            { 'display' => 'VARICELLA' }
          ]
        }
      end

      it 'handles nil safely and falls back' do
        expect(Rails.logger).to receive(:info).with(
          'Immunizations group_name processing',
          hash_including(
            coding_count: 2,
            vaccine_group_lengths: []
          )
        )

        result = described_class.extract_group_name(vaccine_code)
        expect(result).to eq('VARICELLA')
      end
    end

    context 'when coding array is nil' do
      let(:vaccine_code) do
        {
          'text' => 'Test vaccine',
          'coding' => nil
        }
      end

      it 'handles nil coding safely and returns nil' do
        result = described_class.extract_group_name(vaccine_code)
        expect(result).to be_nil
      end
    end

    context 'when VACCINE GROUP: exists but is at a different index' do
      let(:vaccine_code) do
        {
          'text' => 'Pneumococcal vaccine',
          'coding' => [
            { 'code' => '33', 'display' => 'PNEUMOCOCCAL' },
            { 'code' => '152', 'display' => 'VACCINE GROUP: PNEUMOCOCCAL' },
            { 'display' => 'PNEUMOCOCCAL POLYSACCHARIDE PPV23' }
          ]
        }
      end

      it 'extracts from VACCINE GROUP: prefix and ignores other display names' do
        expect(Rails.logger).to receive(:info).with(
          'Immunizations group_name processing',
          hash_including(
            coding_count: 3,
            vaccine_group_lengths: [13]
          )
        )

        result = described_class.extract_group_name(vaccine_code)
        expect(result).to eq('PNEUMOCOCCAL')
      end
    end

    context 'system-based priority fallback' do
      context 'when CVX system is present' do
        let(:vaccine_code) do
          {
            'text' => 'Multiple systems',
            'coding' => [
              { 'code' => '001', 'system' => 'http://hl7.org/fhir/sid/ndc', 'display' => 'NDC Display' },
              { 'code' => '207', 'system' => 'http://hl7.org/fhir/sid/cvx', 'display' => 'CVX Display' },
              { 'code' => '003', 'system' => 'https://fhir.cerner.com/system', 'display' => 'Cerner Display' }
            ]
          }
        end

        it 'prioritizes CVX system display' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(coding_count: 3)
          )

          result = described_class.extract_group_name(vaccine_code)
          expect(result).to eq('CVX Display')
        end
      end

      context 'when Cerner system is highest priority available' do
        let(:vaccine_code) do
          {
            'text' => 'Cerner and NDC',
            'coding' => [
              { 'code' => '001', 'system' => 'http://hl7.org/fhir/sid/ndc', 'display' => 'NDC Display' },
              { 'code' => '002', 'system' => 'https://fhir.cerner.com/ec2458f2-1e24-41c8-b71b-0e701af7583d/codeSet/72',
                'display' => 'Cerner Display' },
              { 'code' => '003', 'system' => 'http://other.system.com', 'display' => 'Other Display' }
            ]
          }
        end

        it 'prioritizes Cerner system display' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(coding_count: 3)
          )

          result = described_class.extract_group_name(vaccine_code)
          expect(result).to eq('Cerner Display')
        end
      end

      context 'when NDC system is highest priority available' do
        let(:vaccine_code) do
          {
            'text' => 'NDC and other',
            'coding' => [
              { 'code' => '001', 'system' => 'http://other.system.com', 'display' => 'Other Display' },
              { 'code' => '002', 'system' => 'http://hl7.org/fhir/sid/ndc', 'display' => 'NDC Display' }
            ]
          }
        end

        it 'prioritizes NDC system display' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(coding_count: 2)
          )

          result = described_class.extract_group_name(vaccine_code)
          expect(result).to eq('NDC Display')
        end
      end

      context 'when only non-priority systems are available' do
        let(:vaccine_code) do
          {
            'text' => 'Other systems',
            'coding' => [
              { 'code' => '001', 'system' => 'http://other.system.com', 'display' => 'First Other Display' },
              { 'code' => '002', 'system' => 'http://another.system.com', 'display' => 'Second Other Display' }
            ]
          }
        end

        it 'falls back to first entry with display' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(coding_count: 2)
          )

          result = described_class.extract_group_name(vaccine_code)
          expect(result).to eq('First Other Display')
        end
      end

      context 'when priority systems have VACCINE GROUP prefix' do
        let(:vaccine_code) do
          {
            'text' => 'CVX with VACCINE GROUP',
            'coding' => [
              { 'code' => '207', 'system' => 'http://hl7.org/fhir/sid/cvx', 'display' => 'VACCINE GROUP: COVID-19' },
              { 'code' => '001', 'system' => 'http://hl7.org/fhir/sid/ndc', 'display' => 'NDC Display' },
              { 'code' => '002', 'system' => 'https://fhir.cerner.com/system', 'display' => 'Cerner Display' }
            ]
          }
        end

        it 'extracts from VACCINE GROUP prefix first' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(coding_count: 3)
          )

          result = described_class.extract_group_name(vaccine_code)
          expect(result).to eq('COVID-19')
        end
      end

      context 'when priority system has empty display' do
        let(:vaccine_code) do
          {
            'text' => 'CVX with empty display',
            'coding' => [
              { 'code' => '207', 'system' => 'http://hl7.org/fhir/sid/cvx', 'display' => '' },
              { 'code' => '001', 'system' => 'http://hl7.org/fhir/sid/ndc', 'display' => 'NDC Display' }
            ]
          }
        end

        it 'skips empty display and falls back to next priority' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(coding_count: 2)
          )

          result = described_class.extract_group_name(vaccine_code)
          expect(result).to eq('NDC Display')
        end
      end
    end
  end
end
