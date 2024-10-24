# frozen_string_literal: true

# Remediation guidelines:
# https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/platform/practices/zero-silent-failures/remediation.md#manual-remediation-process-for-silently-failed-benefits-forms-older-than-2-weeks
require 'faraday/multipart'

module SimpleFormsApi
  module SharePoint
    class ArchiveUploader < Client
      def upload(benefits_intake_uuid:, file_path:)
        @benefits_intake_uuid = benefits_intake_uuid
        @file_path = file_path

        upload_response = upload_payload
        list_item_id = fetch_list_item_id(upload_response)

        update_sharepoint_item(list_item_id:, station_id:)
      rescue => e
        handle_upload_error(e)
      end

      private

      def upload_payload
        payload_path = generate_payload_path
        payload_name = build_payload_name

        upload_to_sharepoint(payload_path, payload_name)
      ensure
        # TODO: will this file be available locally?
        File.delete(payload_path) if payload_path
      end

      # Create a folder, and name it with the date you uploaded
      # the failed forms and the form number of the type of form
      # included. Example folder name 9.10.24-Form4142
      def build_payload_name; end

      # TODO: update this once OFO/VBA gives guidance
      def generate_payload_path; end

      # Get the ID of the uploaded document's list item
      def fetch_list_item_id(pdf_upload_response)
        list_item_uri = extract_list_item_uri(pdf_upload_response)
        retrieve_list_item_id(list_item_uri)
      end

      def extract_list_item_uri(response)
        response.body['d']['ListItemAllFields']['__deferred']['uri']
      end

      def retrieve_list_item_id(uri)
        path = uri.slice(uri.index(base_path)..-1)
        with_monitoring do
          response = sharepoint_connection.get(path)
          list_item_id = response.body.dig('d', 'ID')
          raise ListItemNotFound if list_item_id.nil?

          list_item_id
        end
      end

      def update_sharepoint_item(list_item_id:, station_id:)
        # TODO: this is a placeholder path and will need to be changed
        path = "#{base_path}/_api/Web/Lists/GetByTitle('Submissions')/items(#{list_item_id})"
        with_monitoring do
          sharepoint_connection.post(path) do |req|
            req.headers['Content-Type'] = 'application/json;odata=verbose'
            req.headers['X-HTTP-METHOD'] = 'MERGE'
            req.headers['If-Match'] = '*'
            req.body = build_item_payload(station_id).to_json
          end
        end
      end

      # TODO: this is incomplete and needs to be finished
      def build_item_payload(station_id)
        {
          '__metadata' => { 'type' => 'SP.Data.SubmissionsItem' },
          'StationId' => station_id,
          'UID' => benefits_intake_uuid
        }
      end
    end
  end
end
