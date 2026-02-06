# frozen_string_literal: true

require 'rails_helper'
require 'form_intake/mappers/base_mapper'

RSpec.describe FormIntake::Mappers::BaseMapper do
  let(:form_submission) { create(:form_submission, form_type: 'TEST', form_data: '{"test": "data"}') }
  let(:mapper) { described_class.new(form_submission, 'uuid-123') }

  describe '#initialize' do
    it 'sets form_submission' do
      expect(mapper.form_submission).to eq(form_submission)
    end

    it 'sets benefits_intake_uuid' do
      expect(mapper.benefits_intake_uuid).to eq('uuid-123')
    end
  end

  describe '#to_gcio_payload' do
    it 'raises NotImplementedError' do
      expect { mapper.to_gcio_payload }.to raise_error(NotImplementedError, /must implement #to_gcio_payload/)
    end
  end

  describe '#form_data' do
    it 'returns parsed JSON' do
      expect(mapper.send(:form_data)).to eq({ 'test' => 'data' })
    end
  end

  describe '#form_type' do
    it 'returns form type from form_submission' do
      expect(mapper.send(:form_type)).to eq('TEST')
    end
  end

  describe '#form_submission_id' do
    it 'returns form_submission id' do
      expect(mapper.send(:form_submission_id)).to eq(form_submission.id)
    end
  end

  describe '#map_ssn' do
    it 'combines SSN parts' do
      ssn = { 'first3' => '123', 'middle2' => '45', 'last4' => '6789' }
      expect(mapper.send(:map_ssn, ssn)).to eq('123456789')
    end

    it 'returns nil for missing SSN' do
      expect(mapper.send(:map_ssn, nil)).to be_nil
    end

    it 'returns nil when any part is missing' do
      expect(mapper.send(:map_ssn, { 'first3' => '123', 'last4' => '6789' })).to be_nil
      expect(mapper.send(:map_ssn, { 'first3' => '123', 'middle2' => '45' })).to be_nil
      expect(mapper.send(:map_ssn, { 'middle2' => '45', 'last4' => '6789' })).to be_nil
    end

    it 'returns nil when parts are empty strings' do
      ssn = { 'first3' => '', 'middle2' => '45', 'last4' => '6789' }
      expect(mapper.send(:map_ssn, ssn)).to be_nil
    end
  end

  describe '#map_phone' do
    it 'combines phone parts' do
      phone = { 'area_code' => '555', 'prefix' => '123', 'line_number' => '4567' }
      expect(mapper.send(:map_phone, phone)).to eq('5551234567')
    end

    it 'returns nil for missing phone' do
      expect(mapper.send(:map_phone, nil)).to be_nil
    end

    it 'returns nil when any part is missing' do
      expect(mapper.send(:map_phone, { 'area_code' => '555', 'prefix' => '123' })).to be_nil
      expect(mapper.send(:map_phone, { 'prefix' => '123', 'line_number' => '4567' })).to be_nil
    end
  end

  describe '#map_address' do
    it 'flattens address to single string' do
      address = {
        'street' => '123 Main St',
        'street2' => 'Apt 2',
        'city' => 'Portland',
        'state' => 'OR',
        'zip_code' => { 'first5' => '97201' },
        'country' => 'USA'
      }
      result = mapper.send(:map_address, address)
      expect(result).to eq('123 Main St Apt 2 Portland OR 97201 USA')
    end

    it 'returns nil for missing address' do
      expect(mapper.send(:map_address, nil)).to be_nil
    end

    it 'handles alternate postal_code field' do
      address = { 'street' => '123 Main', 'city' => 'Portland', 'state' => 'OR', 'postal_code' => '97201' }
      result = mapper.send(:map_address, address)
      expect(result).to eq('123 Main Portland OR 97201')
    end

    it 'omits street2 when not present' do
      address = { 'street' => '123 Main', 'city' => 'Portland', 'state' => 'OR', 'postal_code' => '97201' }
      result = mapper.send(:map_address, address)
      expect(result).not_to include('  ') # No double spaces
    end
  end

  describe '#map_date' do
    it 'formats date parts to MM/DD/YYYY format with zero-padding' do
      date = { 'year' => '2024', 'month' => '3', 'day' => '5' }
      expect(mapper.send(:map_date, date)).to eq('03/05/2024')
    end

    it 'handles integer values' do
      date = { 'year' => 2024, 'month' => 3, 'day' => 5 }
      expect(mapper.send(:map_date, date)).to eq('03/05/2024')
    end

    it 'converts string numbers to integers' do
      date = { 'year' => '2024', 'month' => '12', 'day' => '25' }
      expect(mapper.send(:map_date, date)).to eq('12/25/2024')
    end

    it 'returns nil for missing date' do
      expect(mapper.send(:map_date, nil)).to be_nil
    end

    it 'returns nil when any part is missing' do
      expect(mapper.send(:map_date, { 'year' => '2024', 'month' => '3' })).to be_nil
      expect(mapper.send(:map_date, { 'month' => '3', 'day' => '5' })).to be_nil
    end
  end

  describe '#map_full_name' do
    it 'formats full name hash with all parts' do
      name = { 'first' => 'John', 'middle' => 'Michael', 'last' => 'Doe', 'suffix' => 'Jr' }
      result = mapper.send(:map_full_name, name)
      expect(result[:first]).to eq('John')
      expect(result[:middle]).to eq('Michael')
      expect(result[:middle_initial]).to eq('M')
      expect(result[:last]).to eq('Doe')
      expect(result[:suffix]).to eq('Jr')
      expect(result[:full]).to eq('John Michael Doe')
    end

    it 'extracts middle initial from middle name' do
      name = { 'first' => 'John', 'middle' => 'Michael', 'last' => 'Doe' }
      result = mapper.send(:map_full_name, name)
      expect(result[:middle_initial]).to eq('M')
    end

    it 'returns nil for missing name' do
      expect(mapper.send(:map_full_name, nil)).to be_nil
    end

    it 'removes nil values with compact' do
      name = { 'first' => 'John', 'middle' => nil, 'last' => 'Doe' }
      result = mapper.send(:map_full_name, name)
      expect(result.keys).not_to include(:middle)
      expect(result[:full]).to eq('John Doe')
    end
  end
end
