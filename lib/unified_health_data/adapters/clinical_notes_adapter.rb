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

        EMPTY_FIELD = 'None recorded'

        NOTE_TYPES = {
          'PHYSICIAN_PROCEDURE_NOTE' => 'physician_procedure_note',
          'CONSULT_RESULT' => 'consult_result',
          'DISCHARGE_SUMMARY' => 'discharge_summary',
          'OTHER' => 'other'
        }.freeze

        def parse(note)
          record = note['resource']
          return nil unless record

          UnifiedHealthData::ClinicalNotes.new({
                                                 id: record['id'],
                                                 name: get_title(record),
                                                 type: get_record_type(record),
                                                 date: record['date'],
                                                 date_signed: get_date_signed(record),
                                                 written_by: extract_author(record),
                                                 signed_by: extract_authenticator(record),
                                                 location: extract_location(record),
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

        def array_and_has_items(item)
          item.is_a?(Array) && !item.empty?
        end

        def get_title(record)
          content_item = record['content']&.find { |item| item['attachment'] }
          return content_item['title'] if content_item['title']

          return record['type']['text'] if record['type']['text']

          nil
        end

        def extract_authenticator(record)
          # Should work for both VistA and OH formats.
          authenticator = find_contained(
            record,
            record['authenticator']['reference']
          )
          name = authenticator['name']&.find { |n| n['text'] }
          format_name_first_to_last(name) || nil
        end

        def extract_author(record)
          # Should work for both VistA and OH formats.
          if array_and_has_items(record['author'])
            author_ref = record['author'].find { |a| a['reference'] }
            author = find_contained(record, author_ref['reference'])
            name = author['name']&.find { |n| n['text'] }
            return format_name_first_to_last(name) || nil
          end
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

          firstname, lastname = parts
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
              return resource['name'] || nil
            end
          # OH - location is in the custodian field
          elsif record['custodian']['reference']
            resource = find_contained(record, record['custodian']['reference'])
            return resource['name'] || nil
          end
          nil
        end

        def get_note(record)
          if array_and_has_items(record['content'])
            content_item = record['content'].find { |item| item['attachment']['contentType'] == 'text/plain' }

            return content_item['attachment']['data'] if content_item['attachment']
          end
          nil
        end

        # Signing date does not seem to exist in OH data
        def get_date_signed(record)
          if array_and_has_items(record['authenticator']['extension'])
            return record['authenticator']['extension'].find { |e| e['valueDateTime'] }['valueDateTime']
          end

          nil
        end

        def find_contained(record, reference)
          return nil unless reference && record['contained']

          target_id = reference.delete_prefix('#')
          type_id = target_id.split('/')
          resource = record['contained'].detect { |res| res['id'] == type_id[1] }
          return nil unless resource && resource['resourceType'] == type_id[0]

          resource
        end
      end
    end
  end
end
