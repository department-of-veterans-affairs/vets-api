# frozen_string_literal: true

require 'faraday/multipart'

module SimpleFormsApi
  module SharePointService
    class Service
      extend Forwardable
      include Common::Client::Concerns::Monitoring

      class ListItemNotFound < StandardError; end

      STATSD_KEY_PREFIX = 'api.vha.financial_status_report.sharepoint.request'

      attr_reader :settings
      attr_accessor :access_token, :user

      def_delegators :settings, :sharepoint_url, :client_id, :client_secret, :tenant_id, :resource, :service_name,
                     :base_path, :authentication_url

      def initialize
        @settings = initialize_settings
        @access_token = set_sharepoint_access_token
      end

      ##
      # Upload a PDF file to VHA SharePoint
      #
      # @param form_contents [Hash] - The JSON of the form
      # @param form_submission [Form5655Submission] - Persisted submission of the form
      # @param station_id [String] - The VHA station the form belongs to
      #
      # @return [Faraday::Response] - Response from SharePoint upload
      #
      def upload(form_contents:, form_submission:, station_id:)
        set_user_data(form_submission.user_account_id)
        upload_response = upload_pdf(form_contents:, form_submission:, station_id:)
        list_item_id = fetch_list_item_id(upload_response)

        update_sharepoint_item(list_item_id:, form_submission:, station_id:)
      rescue => e
        handle_upload_error(e)
      end

      private

      ##
      # Set the access token for SharePoint authentication from Microsoft Access Control
      #
      # @return [String] - The access token
      #
      def set_sharepoint_access_token
        auth_response = auth_connection.post("/#{tenant_id}/tokens/OAuth/2", auth_params)
        auth_response.body['access_token']
      end

      def auth_params
        {
          grant_type: 'client_credentials',
          client_id: "#{client_id}@#{tenant_id}",
          client_secret:,
          resource: "#{resource}/#{sharepoint_url}@#{tenant_id}"
        }
      end

      def set_user_data(user_account_id)
        user_account = UserAccount.find(user_account_id)
        user_profile = fetch_user_profile(user_account.icn)
        @user = extract_user_info(user_profile)
      end

      # TODO: what is MPI service and can we use it?
      def fetch_user_profile(icn)
        mpi_service.find_profile_by_identifier(identifier: icn, identifier_type: MPI::Constants::ICN)
      end

      def extract_user_info(profile)
        {
          ssn: profile.ssn,
          first_name: profile.given_names.first,
          last_name: profile.family_name
        }
      end

      ##
      # Upload PDF document to SharePoint site
      #
      # @param form_contents [Hash] - Contents to fill form with
      # @param form_submission [Form5655Submission] - Persisted form
      # @param station_id [String] - VHA Station identifier
      #
      # @return [Faraday::Response]
      #
      def upload_pdf(form_contents:, form_submission:, station_id:)
        pdf_path = generate_pdf_path(form_contents, form_submission, station_id)
        file_name = build_file_name(user)

        upload_to_sharepoint(pdf_path, file_name)
      ensure
        File.delete(pdf_path) if pdf_path
      end

      # TODO: this needs to change
      def generate_pdf_path(form_contents, form_submission, station_id)
        PdfFill::Filler.fill_ancillary_form(form_contents, "#{form_submission.id}-#{station_id}", '5655')
      end

      def build_file_name(user)
        "#{DateTime.now.strftime('%Y%m%dT%H%M%S')}_#{user[:ssn].last(4)}_#{user[:last_name].tr(' ', '_')}"
      end

      def upload_to_sharepoint(pdf_path, file_name)
        with_monitoring do
          sharepoint_file_connection.post(file_transfer_url(file_name)) do |req|
            req.headers['Content-Type'] = 'octet/stream'
            req.body = Faraday::UploadIO.new(File.open(pdf_path), 'octet/stream')
          end
        end
      end

      def file_transfer_url(file_name)
        "#{base_path}/_api/Web/GetFolderByServerRelativeUrl('#{base_path}/Submissions')/Files/add(url='#{file_name}.pdf',overwrite=true)"
      end

      ##
      # Get the ID of the uploaded document's list item
      #
      # @param pdf_upload_response [Faraday::Response] - Network response from initial upload
      #
      # @return [Integer]
      #
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

      ##
      # Populate SharePoint list item fields with VHA data
      #
      # @param list_item_id [Integer] - ID of SharePoint list item
      # @param form_submission [Form5655Submission] - Persisted form
      # @param station_id [String] - VHA Station identifier
      #
      # @return [Faraday::Response]
      #
      def update_sharepoint_item(list_item_id:, form_submission:, station_id:)
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

      def build_item_payload(form_submission, station_id)
        {
          '__metadata' => { 'type' => 'SP.Data.SubmissionsItem' },
          'StationId' => station_id,
          'UID' => form_submission.id,
          'SSN' => user[:ssn],
          'Name1' => "#{user[:last_name]}, #{user[:first_name]}"
        }
      end

      def handle_upload_error(error)
        StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
        Rails.logger.error('SharePoint upload failed', error.message)
        raise error
      end

      def auth_connection
        @auth_connection ||= Faraday.new(url: authentication_url, headers: auth_headers) do |conn|
          configure_connection(conn)
        end
      end

      def sharepoint_connection
        @sharepoint_connection ||= Faraday.new(url: "https://#{sharepoint_url}", headers: sharepoint_headers) do |conn|
          configure_connection(conn)
        end
      end

      def sharepoint_file_connection
        @sharepoint_file_connection ||= Faraday.new(url: "https://#{sharepoint_url}",
                                                    headers: sharepoint_headers) do |conn|
          configure_file_connection(conn)
        end
      end

      def configure_connection(conn)
        conn.request :json
        conn.use :breakers
        conn.use Faraday::Response::RaiseError
        conn.response :raise_custom_error, error_prefix: service_name
        conn.response :json
        conn.response :betamocks if mock_enabled?
        conn.adapter Faraday.default_adapter
      end

      def configure_file_connection(conn)
        conn.request :multipart
        conn.request :url_encoded
        configure_connection(conn)
      end

      ##
      # HTTP headers for Microsoft Access Control authentication
      #
      # @return [Hash]
      #
      def auth_headers
        { 'Content-Type' => 'application/x-www-form-urlencoded' }
      end

      ##
      # HTTP headers for uploading documents to SharePoint
      #
      # @return [Hash]
      #
      def sharepoint_headers
        {
          'Authorization' => "Bearer #{access_token}",
          'Accept' => 'application/json;odata=verbose'
        }
      end

      # TODO: we need to set this to VBA
      def initialize_settings
        Settings.vha.sharepoint
      end

      def mpi_service
        @mpi_service ||= MPI::Service.new
      end

      ##
      # Betamocks enabled status from settings
      #
      # @return [Boolean]
      #
      def mock_enabled?
        settings.mock || false
      end
    end
  end
end
