# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/clinical_notes_adapter'

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

  let(:avs_sample_response) do
    JSON.parse(Rails.root.join(
      'spec', 'fixtures', 'unified_health_data', 'after_visit_summary.json'
    ).read)
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
          'date' => '2025-05-15T17:48:51Z',
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

  describe '#parse_avs_with_metadata' do
    context 'happy path' do
      it 'returns the expected fields with binary data included' do
        parsed_avs = adapter.parse_avs_with_metadata(avs_sample_response['entry'][1], '12345', true)

        expect(parsed_avs).to have_attributes(
          {
            'appt_id' => '12345',
            'id' => '15249638961',
            'name' => 'Ambulatory Visit Summary',
            'loinc_codes' => %w[4189669 96345-4],
            'note_type' => 'ambulatory_patient_summary',
            'content_type' => 'application/pdf',
            'binary' => /JVBERi0xLjQKJeLjz9MKMSAwIG9iago8P/i
          }
        )
      end

      it 'returns the expected fields when include_binary is false' do
        parsed_avs = adapter.parse_avs_with_metadata(avs_sample_response['entry'][1], '12345', false)

        expect(parsed_avs).to have_attributes(
          {
            'appt_id' => '12345',
            'id' => '15249638961',
            'name' => 'Ambulatory Visit Summary',
            'loinc_codes' => %w[4189669 96345-4],
            'note_type' => 'ambulatory_patient_summary',
            'content_type' => 'application/pdf',
            'binary' => nil
          }
        )
      end
    end

    context 'edge cases and fallbacks' do
      it 'returns the expected fields for a text only with binary data included' do
        modified_sample = avs_sample_response['entry'][1].deep_dup
        modified_sample['resource']['contained'] = [] # remove the contained array to test content text fallback option
        parsed_avs = adapter.parse_avs_with_metadata(modified_sample, '12345', true)

        expect(parsed_avs).to have_attributes(
          {
            'appt_id' => '12345',
            'id' => '15249638961',
            'name' => 'Ambulatory Visit Summary',
            'loinc_codes' => %w[4189669 96345-4],
            'note_type' => 'ambulatory_patient_summary',
            'content_type' => 'text/plain',
            'binary' => /NjY4IE1hbm4tR3JhbmRzdGFmZiBXQSBWQSBNZWRpY2FsIENlbnRlcgo0OD/i
          }
        )
      end

      it 'returns the expected fields for text only in the contained array' do
        modified_sample = avs_sample_response['entry'][1].deep_dup
        modified_sample['resource']['contained'][0]['contentType'] = 'text/plain'
        parsed_avs = adapter.parse_avs_with_metadata(modified_sample, '12345', true)

        expect(parsed_avs).to have_attributes(
          {
            'appt_id' => '12345',
            'id' => '15249638961',
            'name' => 'Ambulatory Visit Summary',
            'loinc_codes' => %w[4189669 96345-4],
            'note_type' => 'ambulatory_patient_summary',
            'content_type' => 'text/plain',
            'binary' => /JVBERi0xLjQKJeLjz9MKMSAwIG9iago8P/i
          }
        )
      end

      it 'returns the expected fields if XML only in the contained array' do
        modified_sample = avs_sample_response['entry'][1].deep_dup
        modified_sample['resource']['contained'][0]['contentType'] = 'application/xml'
        parsed_avs = adapter.parse_avs_with_metadata(modified_sample, '12345', true)

        expect(parsed_avs).to have_attributes(
          {
            'appt_id' => '12345',
            'id' => '15249638961',
            'name' => 'Ambulatory Visit Summary',
            'loinc_codes' => %w[4189669 96345-4],
            'note_type' => 'ambulatory_patient_summary',
            'content_type' => 'text/plain', # should skip the contained XML and use the content text fallback
            'binary' => /NjY4IE1hbm4tR3JhbmRzdGFmZiBXQSBWQSBNZWRpY2FsIENlbnRlcgo0OD/i
          }
        )
      end

      it 'returns nil if there is no binary data returned even if include_binary is false' do
        modified_sample = avs_sample_response['entry'][1].deep_dup
        modified_sample['resource']['contained'] = [] # remove the contained array
        modified_sample['resource']['content'] = [] # remove the content array
        parsed_avs = adapter.parse_avs_with_metadata(modified_sample, '12345', false)

        expect(parsed_avs).to be_nil
      end

      it 'returns nil if the only binary option is XML' do
        modified_sample = avs_sample_response['entry'][1].deep_dup
        modified_sample['resource']['contained'] = [] # remove the contained array
        modified_sample['resource']['content'] = [{
          'attachment' => {
            'contentType' => 'application/xml',
            'url' => 'http://fake.url.com/Binary/XML-15249651470',
            'title' => 'Ambulatory Visit Summary',
            'creation' => '2025-07-29T17:32:46.000Z'
          },
          'format' => {
            'system' => 'http://fake.system/ValueSet/IHE.FormatCode.codesystem',
            'code' => 'urn:mimeTypeSufficient',
            'display' => 'mimeType Sufficient'
          }
        }] # replace the content array with only an XML option
        parsed_avs = adapter.parse_avs_with_metadata(modified_sample, '12345', true)

        expect(parsed_avs).to be_nil
      end
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
      expect(result.binary[0, 20]).to eq('PD94bWwgdmVyc2lvbj0i')
    end

    it 'keeps data Base64 encoded' do
      result = adapter.parse_ccd_binary(document_ref_entry, 'xml')

      expect(result.binary).to be_a(String)
      expect(result.binary).not_to include('<')
    end

    it 'returns BinaryData object with HTML content' do
      result = adapter.parse_ccd_binary(document_ref_entry, 'html')

      expect(result).to be_a(UnifiedHealthData::BinaryData)
      expect(result.content_type).to eq('text/html')
      expect(result.binary).to be_present
      expect(result.binary[0, 20]).to eq('PCEtLSBEbyBOT1QgZWRp')
    end

    it 'returns BinaryData object with PDF content' do
      result = adapter.parse_ccd_binary(document_ref_entry, 'pdf')

      expect(result).to be_a(UnifiedHealthData::BinaryData)
      expect(result.content_type).to eq('application/pdf')
      expect(result.binary).to be_present
      expect(result.binary[0, 20]).to eq('JVBERi0xLjUKJeLjz9MK')
    end

    it 'raises ArgumentError for unavailable format' do
      # Modify fixture to remove HTML content item
      modified_entry = JSON.parse(document_ref_entry.to_json)
      modified_entry['resource']['content'].reject! do |item|
        item['attachment']['contentType'] == 'text/html'
      end

      expect do
        adapter.parse_ccd_binary(modified_entry, 'html')
      end.to raise_error(ArgumentError, 'Format html not available for this CCD')
    end
  end
end
