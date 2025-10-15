# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/clinical_notes_adapter'
require 'unified_health_data/models/clinical_notes'

RSpec.describe 'ClinicalNotesAdapter' do
  let(:adapter) { UnifiedHealthData::Adapters::ClinicalNotesAdapter.new }
  let(:notes_sample_response) do
    JSON.parse(Rails.root.join(
      'spec', 'fixtures', 'unified_health_data', 'notes_sample_response.json'
    ).read)
  end

  let(:notes_methods_fallback_response) do
    JSON.parse(Rails.root.join(
      'spec', 'fixtures', 'unified_health_data', 'notes_methods_fallback_response.json'
    ).read)
  end

  before do
    allow(UnifiedHealthData::ClinicalNotes).to receive(:new).and_call_original
  end

  describe '#parse' do
    it 'returns the expected fields for happy path for vista note with all fields' do
      parsed_note = adapter.parse(notes_sample_response['vista']['entry'][0])

      expect(parsed_note).to have_attributes(
        {
          'id' => '76ad925b-0c2c-4401-ac0a-13542d6b6ef5',
          'name' => 'CARE COORDINATION HOME TELEHEALTH DISCHARGE NOTE',
          'note_type' => 'physician_procedure_note',
          'loinc_codes' => ['11506-3'],
          'date' => '2025-01-14T09:18:00.000+00:00',
          'date_signed' => '2025-01-14T09:29:26+00:00',
          'written_by' => 'MARCI P MCGUIRE',
          'signed_by' => 'MARCI P MCGUIRE',
          'discharge_date' => nil, # vista records do not have the context.period.end field
          'location' => 'CHYSHR TEST LAB',
          'note' => /VGhpcyBpcyBhIHRlc3QgdGVsZWhlYWx0aCBka/i
        }
      )
    end

    it 'returns the expected fields for happy path for OH note with all fields' do
      parsed_note = adapter.parse(notes_sample_response['oracle-health']['entry'][1])

      expect(parsed_note).to have_attributes(
        {
          'id' => '15249697279',
          'name' => 'Clinical Summary',
          'note_type' => 'discharge_summary',
          'loinc_codes' => %w[4189665 18842-5],
          'date' => '2025-07-29T17:48:51Z',
          'date_signed' => nil, # OH records do not have a date signed field
          'written_by' => 'Victoria A Borland',
          'signed_by' => 'Victoria A Borland',
          'admission_date' => nil,
          'discharge_date' => '2025-07-29T17:48:41Z',
          'location' => '668 Mann-Grandstaff WA VA Medical Center',
          'note' => /Q2xpbmljYWwgU3VtbWFyeSAqIEZpbmFsIFJlcG9/i
        }
      )
    end

    it 'returns the expected fields with alternate fallbacks for all fields' do
      parsed_note = adapter.parse(notes_methods_fallback_response['oracle-health']['entry'][0])

      expect(parsed_note).to have_attributes(
        {
          'id' => '15249697279',
          'name' => 'Inpatient Clinical Summary', # type['text'] fallback
          'note_type' => 'discharge_summary', # based on LOINC code
          'loinc_codes' => %w[4189665 18842-5],
          'date' => '2025-07-29T17:48:51Z',
          'date_signed' => nil,
          # name['text'] fallback (OH has a space after the , in name['text'], vista does not))
          'written_by' => ' Victoria A Borland',
          # name['text'] fallback (OH has a space after the , in name['text'], vista does not))
          'signed_by' => ' Victoria A Borland',
          # So far this doesn't exist in any sample data
          'admission_date' => nil,
          'discharge_date' => '2025-07-29T17:48:41Z',
          'location' => '668 Mann-Grandstaff WA VA Medical Center',
          'note' => /Q2xpbmljYWwgU3VtbWFyeSAqIEZpbmFsIFJlcG9/i
        }
      )
    end

    it 'private methods fail gracefully and returns the expected fields with nil for missing values' do
      parsed_note = adapter.parse(notes_methods_fallback_response['vista']['entry'][0])

      expect(parsed_note).to have_attributes(
        {
          'id' => '76ad925b-0c2c-4401-ac0a-13542d6b6ef5',
          'name' => nil,
          'note_type' => 'other', # based on LOINC code
          'loinc_codes' => nil,
          'date' => nil,
          'date_signed' => nil,
          'written_by' => 'MARCI P MCGUIRE', # alternate #mhv-practitioner-name format
          'signed_by' => nil, # name['text'] fallback
          'admission_date' => nil,
          'discharge_date' => nil,
          'location' => nil,
          'note' => /VGhpcyBpcyBhIHRlc3QgdGVsZWhlYWx0aCBk/i
        }
      )
    end

    it 'returns nil if there is no note data' do
      parsed_note = adapter.parse(notes_methods_fallback_response['vista']['entry'][1])

      expect(parsed_note).to be_nil
    end
  end

  describe '#parse_ccd_metadata' do
    let(:ccd_fixture) do
      JSON.parse(Rails.root.join('spec', 'fixtures', 'unified_health_data', 'ccd_example.json').read)
    end
    let(:document_ref_entry) do
      ccd_fixture['entry'].find { |e| e['resource']['resourceType'] == 'DocumentReference' }
    end

    it 'extracts CCD metadata' do
      result = adapter.parse_ccd_metadata(document_ref_entry)

      expect(result[:type]).to eq('Continuity of Care Document')
      expect(result[:id]).to be_present
      expect(result[:status]).to eq('current')
      expect(result[:available_formats]).to include('xml')
    end

    it 'detects all available formats' do
      result = adapter.parse_ccd_metadata(document_ref_entry)

      expect(result[:available_formats]).to be_an(Array)
      expect(result[:available_formats]).not_to be_empty
    end

    it 'extracts LOINC code' do
      result = adapter.parse_ccd_metadata(document_ref_entry)

      expect(result[:loinc_code]).to be_present
    end
  end

  describe '#parse_ccd_binary' do
    let(:ccd_fixture) do
      JSON.parse(Rails.root.join('spec', 'fixtures', 'unified_health_data', 'ccd_example.json').read)
    end
    let(:document_ref_entry) do
      ccd_fixture['entry'].find { |e| e['resource']['resourceType'] == 'DocumentReference' }
    end

    it 'returns BinaryData object with XML content' do
      result = adapter.parse_ccd_binary(document_ref_entry, 'xml')

      expect(result).to be_a(UnifiedHealthData::BinaryData)
      expect(result.content_type).to eq('application/xml')
      expect(result.binary).to be_present
    end

    it 'keeps data Base64 encoded' do
      result = adapter.parse_ccd_binary(document_ref_entry, 'xml')

      # Verify it's still Base64 encoded (not decoded in adapter)
      expect(result.binary).to be_a(String)
      # Decoded XML should start with XML declaration
      decoded = Base64.decode64(result.binary)
      expect(decoded).to match(/^<\?xml/)
    end

    it 'raises error for invalid format' do
      expect do
        adapter.parse_ccd_binary(document_ref_entry, 'invalid')
      end.to raise_error(ArgumentError, /Invalid format/)
    end

    it 'raises error for unavailable format' do
      # Deep copy fixture to remove HTML without mutating original
      modified_entry = JSON.parse(document_ref_entry.to_json)
      modified_entry['resource']['content'].first['attachment'].delete('html')

      expect do
        adapter.parse_ccd_binary(modified_entry, 'html')
      end.to raise_error(ArgumentError, /Format html not available/)
    end
  end
end
