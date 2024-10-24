# frozen_string_literal: true

require 'faraday/multipart'

module SimpleFormsApi
  module SharePoint
    class Client
      extend Forwardable
      include Common::Client::Concerns::Monitoring

      class ListItemNotFound < StandardError; end

      # TODO: this is a placeholder; add configuration for VBA sharepoint access
      STATSD_KEY_PREFIX = 'api.vba.submission_error_remediation.sharepoint.request'

      attr_reader :settings
      attr_accessor :access_token

      # TODO: these are placeholders; add configuration for VBA sharepoint access
      def_delegators :settings, :authentication_url, :base_path, :client_id, :client_secret, :resource, :service_name,
                     :sharepoint_url, :tenant_id

      def initialize
        @settings = initialize_settings
        @access_token = set_sharepoint_access_token
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

      # TODO: change this to interface with S3 or an intermediary job/service
      def upload_to_sharepoint(payload_path, payload_name)
        with_monitoring do
          sharepoint_file_connection.post(file_creation_url(payload_name)) do |req|
            req.headers['Content-Type'] = 'octet/stream'
            req.body = Faraday::UploadIO.new(File.open(payload_path), 'octet/stream')
          end
        end
      end

      # TODO: this url may need tweaking
      # reference: https://learn.microsoft.com/en-us/sharepoint/dev/sp-add-ins/working-with-folders-and-files-with-rest
      def file_creation_url(payload_name)
        "#{base_path}/_api/Web/GetFolderByServerRelativeUrl('Benefits Portfolio/Documents/VBA Manual Form Upload')/" \
          "Files/add(url='#{payload_name}.zip',overwrite=true)"
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

      # TODO: this is a placeholder; add configuration for VBA sharepoint access
      def initialize_settings
        Settings.vba.sharepoint
      end
    end
  end
end
