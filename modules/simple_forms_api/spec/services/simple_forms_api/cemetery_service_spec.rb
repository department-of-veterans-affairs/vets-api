# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::CemeteryService do
  let(:mock_json_data) do
    {
      'data' => [
        {
          'id' => '915',
          'type' => 'preneeds_cemeteries',
          'attributes' => {
            'cemetery_id' => '915',
            'name' => 'ABRAHAM LINCOLN NATIONAL CEMETERY',
            'cemetery_type' => 'N',
            'num' => '915'
          }
        },
        {
          'id' => '944',
          'type' => 'preneeds_cemeteries',
          'attributes' => {
            'cemetery_id' => '944',
            'name' => 'CALVERTON NATIONAL CEMETERY',
            'cemetery_type' => 'N',
            'num' => '944'
          }
        }
      ]
    }
  end

  describe '.all' do
    context 'when JSON file exists and is valid' do
      before do
        allow(File).to receive(:exist?).with(described_class::CEMETERIES_FILE_PATH).and_return(true)
        allow(File).to receive(:read).with(described_class::CEMETERIES_FILE_PATH).and_return(mock_json_data.to_json)
      end

      it 'memoizes the result' do
        service_instance = described_class.new

        expect(File).to receive(:read).once

        service_instance.all
        service_instance.all # Second call should use memoized result
      end
    end

    context 'when JSON file does not exist' do
      before do
        allow(File).to receive(:exist?).with(described_class::CEMETERIES_FILE_PATH).and_return(false)
      end

      it 'returns empty array' do
        result = described_class.all
        expect(result).to eq([])
      end

      it 'does not attempt to read the file' do
        expect(File).not_to receive(:read)
        described_class.all
      end
    end

    context 'when JSON file contains invalid JSON' do
      before do
        allow(File).to receive(:exist?).with(described_class::CEMETERIES_FILE_PATH).and_return(true)
        allow(File).to receive(:read).with(described_class::CEMETERIES_FILE_PATH).and_return('invalid json')
        allow(Rails.logger).to receive(:error)
      end

      it 'returns empty array' do
        result = described_class.all
        expect(result).to eq([])
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Failed to parse cemeteries JSON/)
        described_class.all
      end
    end

    context 'when JSON file has no data key' do
      before do
        allow(File).to receive(:exist?).with(described_class::CEMETERIES_FILE_PATH).and_return(true)
        allow(File).to receive(:read).with(described_class::CEMETERIES_FILE_PATH).and_return('{}')
      end

      it 'returns empty array' do
        result = described_class.all
        expect(result).to eq([])
      end
    end

    context 'when file read raises an error' do
      before do
        allow(File).to receive(:exist?).with(described_class::CEMETERIES_FILE_PATH).and_return(true)
        allow(File).to receive(:read).with(described_class::CEMETERIES_FILE_PATH).and_raise(Errno::ENOENT)
        allow(Rails.logger).to receive(:error)
      end

      it 'returns empty array' do
        result = described_class.all
        expect(result).to eq([])
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Failed to load cemeteries/)
        described_class.all
      end
    end
  end

  describe 'CEMETERIES_FILE_PATH constant' do
    it 'points to the correct file path' do
      expected_path = Rails.root.join('modules', 'simple_forms_api', 'app', 'json', 'cemeteries.json')
      expect(described_class::CEMETERIES_FILE_PATH).to eq(expected_path)
    end
  end
end
