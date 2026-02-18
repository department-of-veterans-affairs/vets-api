# frozen_string_literal: true

require 'rails_helper'
require 'form_intake/mappers/registry'
require 'form_intake/mappers/base_mapper'

RSpec.describe FormIntake::Mappers::Registry do
  describe '.mapper_for' do
    context 'when form has mapper' do
      before do
        stub_const('FormIntake::Mappers::Registry::FORM_MAPPERS', {
                     '21P-601' => FormIntake::Mappers::BaseMapper
                   })
      end

      it 'returns mapper class' do
        expect(described_class.mapper_for('21P-601')).to eq(FormIntake::Mappers::BaseMapper)
      end
    end

    context 'when form has no mapper' do
      it 'raises MappingNotFoundError' do
        expect { described_class.mapper_for('UNKNOWN') }
          .to raise_error(FormIntake::Mappers::MappingNotFoundError, /UNKNOWN/)
      end

      it 'includes form type in error message' do
        expect { described_class.mapper_for('TEST-FORM') }
          .to raise_error(FormIntake::Mappers::MappingNotFoundError, /TEST-FORM/)
      end
    end
  end

  describe '.mapper?' do
    before do
      stub_const('FormIntake::Mappers::Registry::FORM_MAPPERS', {
                   '21P-601' => FormIntake::Mappers::BaseMapper
                 })
    end

    it 'returns true for mapped form' do
      expect(described_class.mapper?('21P-601')).to be true
    end

    it 'returns false for unmapped form' do
      expect(described_class.mapper?('UNKNOWN')).to be false
    end
  end

  describe '.mapped_forms' do
    before do
      stub_const('FormIntake::Mappers::Registry::FORM_MAPPERS', {
                   '21P-601' => FormIntake::Mappers::BaseMapper,
                   '21-0966' => FormIntake::Mappers::BaseMapper
                 })
    end

    it 'returns list of form types' do
      expect(described_class.mapped_forms).to match_array(%w[21P-601 21-0966])
    end

    it 'returns empty array when no mappers' do
      stub_const('FormIntake::Mappers::Registry::FORM_MAPPERS', {})
      expect(described_class.mapped_forms).to eq([])
    end
  end
end
