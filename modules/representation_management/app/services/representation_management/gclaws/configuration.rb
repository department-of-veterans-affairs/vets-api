# frozen_string_literal: true

# HTTP client configuration for the RepresentationManagement::GCLAWS::Client
#
module RepresentationManagement
  module GCLAWS
    class Configuration
      DEFAULT_SORT_PARAMS = {
        'agents' => {
          'sortColumn' => 'LastName',
          'sortOrder' => 'ASC'
        },
        'attorneys' => {
          'sortColumn' => 'LastName',
          'sortOrder' => 'ASC'
        },
        'representatives' => {
          'sortColumn' => 'LastName',
          'sortOrder' => 'ASC'
        },
        'veteran_service_organizations' => {
          'sortColumn' => 'Organization.OrganizationName',
          'sortOrder' => 'ASC'
        }
      }.freeze

      URL_MAPPING = {
        'agents' => Settings.gclaws.accreditation.agents.url,
        'attorneys' => Settings.gclaws.accreditation.attorneys.url,
        'representatives' => Settings.gclaws.accreditation.representatives.url,
        'veteran_service_organizations' => Settings.gclaws.accreditation.veteran_service_organizations.url
      }.freeze

      def initialize(type:, page:, page_size:)
        @type = type
        @page = page
        @page_size = page_size
      end

      def connection
        Faraday.new(url:, params:, headers:) do |conn|
          conn.request :json
          conn.response :json, content_type: /\bjson$/
          conn.adapter Faraday.default_adapter
        end
      end

      private

      def api_key
        Settings.gclaws.accreditation.api_key
      end

      def headers
        {
          'x-api-key' => api_key
        }
      end

      def params
        DEFAULT_SORT_PARAMS[@type].merge({ 'page' => @page, 'pageSize' => @page_size })
      end

      def url
        URL_MAPPING[@type]
      end
    end
  end
end
