# frozen_string_literal: true

require 'faraday/multipart'

module SimpleFormsApi
  module SharePoint
    class Client
      extend Forwardable
      include Common::Client::Concerns::Monitoring

      class ListItemNotFound < StandardError; end

      # TODO: this is a placeholder; add configuration for OFO/VBA sharepoint access
      STATSD_KEY_PREFIX = 'api.ofo.submission_error_remediation.sharepoint.request'

      attr_reader :settings
      attr_accessor :access_token

      # TODO: these are placeholders; add configuration for OFO/VBA sharepoint access
      def_delegators :settings, :authentication_url, :base_path, :client_id, :client_secret, :resource, :service_name,
                     :sharepoint_url, :tenant_id

      def initialize
        @settings = initialize_settings
        @access_token = set_sharepoint_access_token
      end

      def upload(form_contents:, form_submission:, station_id:)
        upload_response = upload_payload(form_contents:, form_submission:, station_id:)
        list_item_id = fetch_list_item_id(upload_response)

        update_sharepoint_item(list_item_id:, form_submission:, station_id:)
      rescue => e
        handle_upload_error(e)
      end

      private

      def set_sharepoint_access_token
        auth_response = auth_connection.post("/#{tenant_id}/tokens/OAuth/2", auth_params)
        auth_response.body['access_token']
      end

      def auth_params
        {
          client_id: "#{client_id}@#{tenant_id}",
          client_secret:,
          grant_type: 'client_credentials',
          resource: "#{resource}/#{sharepoint_url}@#{tenant_id}"
        }
      end

      def upload_payload(form_contents:, form_submission:, station_id:)
        payload_path = generate_payload_path
        payload_name = build_payload_name

        upload_to_sharepoint(payload_path, payload_name)
      ensure
        # TODO: will this file be available locally?
        File.delete(payload_path) if payload_path
      end

      # TODO: update this once OFO/VBA gives guidance
      def build_payload_name; end

      # TODO: update this once OFO/VBA gives guidance
      def generate_payload_path; end

      # TODO: change this to interface with S3 or an intermediary job/service
      def upload_to_sharepoint(payload_path, payload_name)
        with_monitoring do
          sharepoint_file_connection.post(file_transfer_url(payload_name)) do |req|
            req.headers['Content-Type'] = 'octet/stream'
            req.body = Faraday::UploadIO.new(File.open(payload_path), 'octet/stream')
          end
        end
      end

      # TODO: confirm this is the correct payload url
      def file_transfer_url(payload_name)
        "#{base_path}/_api/Web/GetFolderByServerRelativeUrl('#{base_path}/Submissions')/" \
          "Files/add(url='#{payload_name}.zip',overwrite=true)"
      end

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

      def update_sharepoint_item(list_item_id:, form_submission:, station_id:)
        # TODO: this is a placeholder path and will need to be changed
        path = "#{base_path}/_api/Web/Lists/GetByTitle('Submissions')/items(#{list_item_id})"
        with_monitoring do
          sharepoint_connection.post(path) do |req|
            req.headers['Content-Type'] = 'application/json;odata=verbose'
            req.headers['X-HTTP-METHOD'] = 'MERGE'
            req.headers['If-Match'] = '*'
            req.body = build_item_payload(form_submission, station_id).to_json
          end
        end
      end

      # TODO: this is a holdover from VHA logic and will need changed
      def build_item_payload(form_submission, station_id)
        {
          '__metadata' => { 'type' => 'SP.Data.SubmissionsItem' },
          'StationId' => station_id,
          'UID' => form_submission.id
          # 'SSN' => user[:ssn],
          # 'Name1' => "#{user[:last_name]}, #{user[:first_name]}"
        }
      end

      def handle_upload_error(error)
        StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
        Rails.logger.error('SharePoint upload failed', error.message)
        raise error
      end

      def auth_connection
        @auth_connection ||= new_connection(headers: auth_headers)
      end

      def sharepoint_connection
        @sharepoint_connection ||= new_connection
      end

      def sharepoint_file_connection
        @sharepoint_file_connection ||= new_connection(configuration: :file_connection)
      end

      def new_connection(url: "https://#{sharepoint_url}", headers: sharepoint_headers, configuration: :connection)
        Faraday.new(url:, headers:) { |conn| method(configuration).call(conn) }
      end

      def connection(connection)
        connection.request :json
        connection.use :breakers
        connection.use Faraday::Response::RaiseError
        connection.response :raise_custom_error, error_prefix: service_name
        connection.response :json
        connection.response :betamocks if mock_enabled?
        connection.adapter Faraday.default_adapter
      end

      def file_connection(connection)
        connection.request :multipart
        connection.request :url_encoded
        configure_connection(connection)
      end

      # HTTP headers for Microsoft Access Control authentication
      def auth_headers
        { 'Content-Type' => 'application/x-www-form-urlencoded' }
      end

      # HTTP headers for uploading documents to SharePoint
      def sharepoint_headers
        {
          'Authorization' => "Bearer #{access_token}",
          'Accept' => 'application/json;odata=verbose'
        }
      end

      # TODO: this is a placeholder; add configuration for OFO/VBA sharepoint access
      def initialize_settings
        Settings.ofo.sharepoint
      end
    end
  end
end
