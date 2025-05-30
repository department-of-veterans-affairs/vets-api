# frozen_string_literal: true

require 'faraday/multipart'
require 'debt_management_center/sharepoint/pdf_errors'
require 'debt_management_center/sharepoint/errors'

Faraday::Response.register_middleware sharepoint_pdf_errors: DebtManagementCenter::Sharepoint::PdfErrors
Faraday::Response.register_middleware sharepoint_errors: DebtManagementCenter::Sharepoint::Errors

module DebtManagementCenter
  module Sharepoint
    class Request
      extend Forwardable
      include Common::Client::Concerns::Monitoring

      class ListItemNotFound < StandardError; end

      STATSD_KEY_PREFIX = 'api.vha.financial_status_report.sharepoint.request'

      attr_reader :settings
      attr_accessor :user

      def_delegators :settings, :sharepoint_url, :client_id, :client_secret, :tenant_id, :resource, :service_name,
                     :base_path, :authentication_url

      def initialize
        @settings = initialize_settings
      end

      def access_token
        @access_token ||= set_sharepoint_access_token
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
        @user = set_user_data(form_submission.user_account_id)

        # Upload PDF with retry
        upload_response = with_sharepoint_retry('PDF upload') do
          upload_pdf(form_contents:, form_submission:, station_id:)
        end

        # Get list item ID with retry
        list_item_id = with_sharepoint_retry('get list item') do
          get_pdf_list_item_id(upload_response)
        end

        # Update list item fields with retry
        resp = with_sharepoint_retry('update metadata') do
          update_list_item_fields(list_item_id:, form_submission:, station_id:)
        end

        if resp.success?
          StatsD.increment("#{STATSD_KEY_PREFIX}.success")
        else
          StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
        end
        resp
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
        Rails.logger.error('Sharepoint Upload failed', e.message)
        raise e
      end

      private

      ##
      # Set the access token for SharePoint authentication from Microsoft Access Control
      #
      # @return [String] - The access token
      #
      def set_sharepoint_access_token
        auth_response = auth_connection.post("/#{tenant_id}/tokens/OAuth/2", {
                                               grant_type: 'client_credentials',
                                               client_id: "#{client_id}@#{tenant_id}",
                                               client_secret:,
                                               resource: "#{resource}/#{sharepoint_url}@#{tenant_id}"
                                             })

        auth_response.body['access_token']
      end

      def set_user_data(user_account_id)
        user_account = UserAccount.find(user_account_id)
        user_profile = mpi_service.find_profile_by_identifier(identifier: user_account.icn,
                                                              identifier_type: MPI::Constants::ICN)

        {
          ssn: user_profile.profile.ssn,
          first_name: user_profile.profile.given_names.first,
          last_name: user_profile.profile.family_name
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
        pdf_path = PdfFill::Filler.fill_ancillary_form(form_contents, "#{form_submission.id}-#{station_id}", '5655')
        fsr_pdf = File.open(pdf_path)

        file_name = "#{DateTime.now.strftime('%Y%m%dT%H%M%S')}_#{user[:ssn].last(4)}_#{user[:last_name].tr(' ', '_')}"

        file_transfer_path =
          "#{base_path}/_api/Web/GetFolderByServerRelativeUrl('#{base_path}/Submissions')" \
          "/Files/add(url='#{file_name}.pdf',overwrite=true)"

        with_monitoring do
          response = sharepoint_file_connection.post(file_transfer_path) do |req|
            req.headers['Content-Type'] = 'octet/stream'
            req.headers['Content-Length'] = fsr_pdf.size.to_s
            req.body = Faraday::UploadIO.new(fsr_pdf, 'octet/stream')
          end

          File.delete(pdf_path)

          response
        end
      end

      ##
      # Get the ID of the uploaded document's list item
      #
      # @param pdf_upload_response [Faraday::Response] - Network response from initial upload
      #
      # @return [Number]
      #
      def get_pdf_list_item_id(pdf_upload_response)
        uri = pdf_upload_response.body['d']['ListItemAllFields']['__deferred']['uri']
        path = uri.slice(uri.index(base_path)..-1)

        with_monitoring do
          get_item_response = sharepoint_connection.get(path)

          list_item_id = get_item_response.body.dig('d', 'ID')
          raise ListItemNotFound if list_item_id.nil?

          list_item_id
        end
      end

      ##
      # Populate data columns with properties needed by VHA
      #
      # @param list_item_id[Number] - ID of SharePoint list item
      # @param form_submission [Form5655Submission] - Persisted form
      # @param station_id [String] - VHA Station identifier
      #
      # @return [Faraday::Response]
      #
      def update_list_item_fields(list_item_id:, form_submission:, station_id:)
        path = "#{base_path}/_api/Web/Lists/GetByTitle('Submissions')/items(#{list_item_id})"
        with_monitoring do
          sharepoint_connection.post(path) do |req|
            req.headers['Content-Type'] = 'application/json;odata=verbose'
            req.headers['X-HTTP-METHOD'] = 'MERGE'
            req.headers['If-Match'] = '*'
            req.body = {
              '__metadata' => {
                'type' => 'SP.Data.SubmissionsItem'
              },
              'StationId' => station_id,
              'UID' => form_submission.id,
              'SSN' => user[:ssn],
              'Name1' => "#{user[:last_name]}, #{user[:first_name]}"
            }.to_json
          end
        end
      end

      def auth_connection
        Faraday.new(url: authentication_url, headers: auth_headers) do |conn|
          conn.request :url_encoded
          conn.use(:breakers, service_name:)
          conn.use Faraday::Response::RaiseError
          conn.response :raise_custom_error, error_prefix: service_name
          conn.response :json
          conn.response :betamocks if mock_enabled?
          conn.adapter Faraday.default_adapter
        end
      end

      def sharepoint_connection
        Faraday.new(url: "https://#{sharepoint_url}", headers: sharepoint_headers) do |conn|
          conn.request :json
          conn.use(:breakers, service_name:)
          conn.use Faraday::Response::RaiseError
          if Flipper.enabled?(:debts_sharepoint_error_logging)
            conn.response :sharepoint_errors, error_prefix: service_name
          else
            conn.response :raise_custom_error, error_prefix: service_name
          end
          conn.response :json
          conn.response :betamocks if mock_enabled?
          conn.adapter Faraday.default_adapter
        end
      end

      def sharepoint_file_connection
        Faraday.new(url: "https://#{sharepoint_url}", headers: sharepoint_headers) do |conn|
          conn.request :multipart
          conn.request :url_encoded
          conn.use(:breakers, service_name:)
          conn.use Faraday::Response::RaiseError
          if Flipper.enabled?(:debts_sharepoint_error_logging)
            conn.response :sharepoint_pdf_errors, error_prefix: service_name
          else
            conn.response :raise_custom_error, error_prefix: service_name
          end
          conn.response :json
          conn.response :betamocks if mock_enabled?
          conn.adapter Faraday.default_adapter
        end
      end

      # retry sharepoint operation with exponential backoff
      def with_sharepoint_retry(operation_name, max_attempts = 3)
        attempts = 0
        begin
          attempts += 1
          yield
        rescue => e
          if attempts < max_attempts
            delay = (2**attempts) * 0.25 # 0.5s, 1s, 2s ...
            Rails.logger.warn("SharePoint #{operation_name} failed, retrying in #{delay}s: #{e.message}")
            sleep(delay)
            retry
          else
            Rails.logger.error("SharePoint #{operation_name} failed after #{max_attempts} attempts: #{e.message}")
            raise
          end
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
          'Authorization' => "Bearer #{access_token}",
          'Accept' => 'application/json;odata=verbose'
        }
      end

      def initialize_settings
        @settings = Settings.vha.sharepoint
      end

      def mpi_service
        @service ||= MPI::Service.new
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
