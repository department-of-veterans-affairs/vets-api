# frozen_string_literal: true

module DebtManagementCenter
  module Sharepoint
    class Request
      extend Forwardable
      include Common::Client::Concerns::Monitoring

      STATSD_KEY_PREFIX = 'api.vha.financial_status_report.sharepoint.request'

      attr_reader :settings
      attr_accessor :access_token

      def_delegators :settings, :sharepoint_url, :client_id, :client_secret, :tenant_id, :resource, :service_name,
                     :base_path, :authentication_url

      def initialize
        @settings = initialize_settings
      end

      ##
      # Upload a PDF file of 5655 form to VHA SharePoint
      #
      # @param form_contents [Hash] - The JSON of the form
      # @param form_submission [Form5655Submission] - Persisted submission of the form
      # @param station_id [String] - The VHA station the form belongs to
      #
      # @return [Faraday::Response] - Response from SharePoint upload
      #
      def upload(form_contents:, form_submission:, station_id:)
        set_sharepoint_access_token

        pdf_path = PdfFill::Filler.fill_ancillary_form(form_contents, "#{form_submission.id}-#{station_id}", '5655')
        fsr_pdf = File.open(pdf_path)
        user = User.find(form_submission.user_uuid)
        file_name = "#{DateTime.now.strftime('%Y%m%dT%H%M')}_#{user.ssn.last(4)}_#{user.last_name}"

        file_transfer_path =
          "/_api/Web/GetFolderByServerRelativeUrl('#{@base_path}/Submissions')" \
          "/Files/add(url='#{file_name}.pdf',overwrite=true)"

        sharepoint_connection.post(file_transfer_path) do |req|
          req.headers['Content-Type'] = 'octet/stream'
          req.headers['Content-Length'] = fsr_pdf.size.to_s
          req.body = Faraday::UploadIO.new(fsr_pdf, 'octet/stream')
        end
      end

      private

      ##
      # Set the access token for SharePoint authentication from Microsoft Access Control
      #
      # @return [String] - The access token
      #
      def set_sharepoint_access_token
        auth_response = auth_connection.post("/#{@tenant_id}/tokens/OAuth/2", {
                                               grant_type: 'client_credentials',
                                               client_id: "#{@client_id}@#{@tenant_id}",
                                               client_secret: @client_secret,
                                               resource: "#{@resource}/#{@url}@#{@tenant_id}"
                                             })

        @access_token = JSON.parse(auth_response.body)['access_token']
      end

      def auth_connection
        Faraday.new(url: @authentication_url, headers: auth_headers) do |conn|
          conn.request :json
          conn.use :breakers
          conn.use Faraday::Response::RaiseError
          conn.response :raise_error, error_prefix: service_name
          conn.response :json
          conn.response :betamocks if mock_enabled?
          conn.adapter Faraday.default_adapter
        end
      end

      def sharepoint_connection
        Faraday.new(url: @sharepoint_url, headers: sharepoint_headers) do |conn|
          conn.request :json
          conn.use :breakers
          conn.use Faraday::Response::RaiseError
          conn.response :raise_error, error_prefix: @service_name
          conn.response :json
          conn.response :betamocks if mock_enabled?
          conn.adapter Faraday.default_adapter
        end
      end

      ##
      # HTTP headers for Microsoft Access Control authentication
      #
      # @return [Hash]
      #
      def auth_headers
        {
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      end

      ##
      # HTTP headers for uploading documents to SharePoint
      #
      # @return [Hash]
      #
      def sharepoint_headers
        {
          'Authorization' => "Bearer #{@access_token}",
          'Accept' => 'application/json;odata=verbose'
        }
      end

      def initialize_settings
        @settings = Settings.vha.sharepoint
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
