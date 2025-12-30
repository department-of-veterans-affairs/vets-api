# frozen_string_literal: true

require 'rails_helper'
require 'burials/bpds/formatter'
RSpec.describe Burials::BPDS::Formatter do
  let(:schema_path) do
    Rails.root.join('modules', 'burials', 'spec', 'fixtures', 'bpds', '530ez_v2.0.json')
  end
  let(:schema) { JSON.parse(File.read(schema_path)) }
  let(:claim) { create(:burials_saved_claim) }

  describe '#format' do
    it 'conforms to BPDS 530EZ v2.0 schema structure' do
      parsed_form = JSON.parse(claim.form)
      formatter = described_class.new(parsed_form)
      result = formatter.format

      # Validate all top-level keys are present in schema
      result.each_key do |key|
        expect(schema.keys).to include(key), "Unexpected key in result: #{key}"
      end

      # Validate no extra keys beyond schema
      schema_keys = schema.keys
      expect(result.keys).to all(be_in(schema_keys))

      expect(result['veteranName']).to be_present
      expect(result['veteranSsn']).to be_present
      expect(result['veteranDob']).to be_present

      # Check date format structure
      if result['veteranDob']
        expect(result['veteranDob']).to have_key('month')
        expect(result['veteranDob']).to have_key('day')
        expect(result['veteranDob']).to have_key('year')
      end

      # Check periodsOfService structure
      expect(result['periodsOfService']).to be_an(Array)
      expect(result['periodsOfService'].first).to have_key('enteredService')
      expect(result['periodsOfService'].first).to have_key('separatedFromService')
    end
  end
end
