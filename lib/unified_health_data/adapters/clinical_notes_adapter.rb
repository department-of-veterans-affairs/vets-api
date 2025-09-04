# frozen_string_literal: true

module UnifiedHealthData
  module V2
    module Adapters
      class ClinicalNotesAdapter
        LOINC_CODES = {
          '11506-3' => 'PHYSICIAN_PROCEDURE_NOTE',
          '11488-4' => 'CONSULT_RESULT',
          '18842-5' => 'DISCHARGE_SUMMARY'
        }.freeze

        NOTE_TYPES = {
          'PHYSICIAN_PROCEDURE_NOTE' => 'physician_procedure_note',
          'CONSULT_RESULT' => 'consult_result',
          'DISCHARGE_SUMMARY' => 'discharge_summary',
          'OTHER' => 'other'
        }.freeze

        FHIR_RESOURCE_TYPES = {
          BUNDLE: 'Bundle',
          DIAGNOSTIC_REPORT: 'DiagnosticReport',
          DOCUMENT_REFERENCE: 'DocumentReference',
          LOCATION: 'Location',
          OBSERVATION: 'Observation',
          ORGANIZATION: 'Organization',
          PRACTITIONER: 'Practitioner'
        }.freeze

        def parse(note)
          record = note['resource']
          return nil unless record && get_note(record)

          UnifiedHealthData::ClinicalNotes.new({
                                                 id: record['id'],
                                                 name: get_title(record),
                                                 note_type: get_record_type(record),
                                                 loinc_codes: get_loinc_codes(record),
                                                 date: record['date'],
                                                 date_signed: get_date_signed(record),
                                                 written_by: extract_author(record),
                                                 signed_by: extract_authenticator(record),
                                                 location: extract_location(record),
                                                 discharge_date: record['context']&.dig('period', 'end') || nil,
                                                 note: get_note(record)
                                               })
        end

        private

        def get_record_type(record)
          LOINC_CODES.each do |key, value|
            return NOTE_TYPES[value] if record['type']['coding']&.any? { |coding| coding['code'] == key }
          end
          NOTE_TYPES['OTHER']
        end

        def get_loinc_codes(record)
          record['type']['coding']&.map { |coding| coding['code'] if coding['code'] }
        end

        def array_and_has_items(item)
          item.is_a?(Array) && !item.empty?
        end

        def get_title(record)
          content_item = record['content']&.find { |item| item['attachment'] }
          return content_item['attachment']['title'] if content_item['attachment']['title']

          record['type']['text'] if record['type']['text']
        rescue
          nil
        end

        def extract_authenticator(record)
          # Should work for both VistA and OH formats.
          authenticator = find_contained(
            record,
            record['authenticator']['reference'],
            FHIR_RESOURCE_TYPES[:PRACTITIONER]
          )
          name = authenticator['name']&.find { |n| n['text'] }
          format_name_first_to_last(name) if name
        rescue
          nil
        end

        def extract_author(record)
          # Should work for both VistA and OH formats.
          if array_and_has_items(record['author'])
            author_ref = record['author'].find { |a| a['reference'] }
            author = find_contained(record, author_ref['reference'], FHIR_RESOURCE_TYPES[:PRACTITIONER])
            name = author['name']&.find { |n| n['text'] }
            format_name_first_to_last(name) if name
          end
        rescue
          nil
        end

        def format_name_first_to_last(name)
          if name.is_a?(Hash)
            if name.key?('family') && name.key?('given')
              firstname = name['given']&.join(' ')
              lastname = name['family']
              return "#{firstname} #{lastname}"
            end

            parts = name['text']&.split(',')
            return name['text'] if parts&.length != 2

            lastname, firstname = parts
            return "#{firstname} #{lastname}"
          end

          parts = name.split(',')
          return name if parts.length != 2

          lastname, firstname = parts
          "#{firstname} #{lastname}"
        rescue
          nil
        end

        def extract_location(record)
          # VistA - location is in the context.related array
          if array_and_has_items(record['context']['related'])
            reference = record['context']['related'].find { |r| r['reference'] }['reference']
            if reference
              resource = find_contained(record, reference)
              resource['name'] || nil
            end
          # OH - location is in the custodian field
          elsif record['custodian']['reference']
            resource = find_contained(record, record['custodian']['reference'], FHIR_RESOURCE_TYPES[:LOCATION])
            resource['name'] || nil
          end
        rescue
          nil
        end

        def get_note(record)
          if array_and_has_items(record['content'])
            content_item = record['content'].find { |item| item['attachment']['contentType'] == 'text/plain' }

            content_item['attachment']['data'] if content_item['attachment']
          end
        rescue
          nil
        end

        # Signing date does not seem to exist in OH data
        def get_date_signed(record)
          if array_and_has_items(record['authenticator']['extension'])
            record['authenticator']['extension'].find { |e| e['valueDateTime'] }['valueDateTime']
          end
        rescue
          nil
        end

        def find_contained(record, reference, type = nil)
          return nil unless reference && record['contained']

          if reference.start_with?('#')
            # Reference is in the format #mhv-resourceType-id
            target_id = reference.delete_prefix('#')
            resource = record['contained'].detect { |res| res['id'] == target_id }
            nil unless resource && resource['resourceType'] == type
          else
            # Reference is in the format ResourceType/id
            type_id = reference.split('/')
            resource = record['contained'].detect { |res| res['id'] == type_id.last }
            unless resource && (resource['resourceType'] == type_id.first || resource['resourceType'] == type)
              return nil
            end
          end
          resource
        end
      end
    end
  end
end
