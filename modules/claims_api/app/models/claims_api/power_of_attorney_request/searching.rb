# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    module Searching
      module Query
        module Page
          module Size
            # For the moment, these values duplicate the behavior of BGS.
            DEFAULT = 25
            MAX = 100
            MIN = 1
          end
        end

        module Sort
          module Fields
            ALL = [
              CREATED_AT = 'createdAt'
            ].freeze
          end

          module Orders
            ALL = [
              ASCENDING = 'asc',
              DESCENDING = 'desc'
            ].freeze
          end
        end
      end

      def search(query)
        total_count = 0
        poa_requests = []

        begin
          response = perform_request(query)
          result = response['POARequestRespondReturnVO'].to_h
          total_count = result['totalNbrOfRecords'].to_i

          poa_requests = result['poaRequestRespondReturnVOList']
          poa_requests = Array.wrap(poa_requests).map! do |data|
            Load.perform(data)
          end
        rescue BGSClient::Error::BGSFault => e
          # Sometimes this empty result is for valid reasons, i.e. a filter
          # combo that just happens to have no records. Other times it is
          # due to something like a non-existent POA code, which is an
          # invalid request from the client. But the BGS response looks the
          # same in either case so we can't distinguish between them.
          raise unless e.message == 'No Record Found'
        end

        [
          total_count,
          poa_requests
        ]
      end

      private

      SORT_ORDER_MAP = {
        Query::Sort::Orders::ASCENDING => 'ASCENDING',
        Query::Sort::Orders::DESCENDING => 'DESCENDING'
      }.freeze

      SORT_FIELD_MAP = {
        Query::Sort::Fields::CREATED_AT => 'DATE_RECEIVED'
      }.freeze

      def perform_request(query) # rubocop:disable Metrics/MethodLength
        action =
          BGSClient::Definitions::
            ManageRepresentativeService::
            ReadPoaRequest::
            DEFINITION

        BGSClient.perform_request(action:) do |xml, data_aliaz|
          filter = query[:filter]

          xml[data_aliaz].SecondaryStatusList do
            filter[:statuses].each do |status|
              xml.SecondaryStatus(status)
            end
          end

          xml[data_aliaz].POACodeList do
            filter[:poaCodes].each do |poa_code|
              xml.POACode(poa_code)
            end
          end

          xml[data_aliaz].POARequestParameter do
            page = query[:page]
            xml.pageIndex(page[:number])
            xml.pageSize(page[:size])

            sort = query[:sort]
            xml.poaSortField(SORT_FIELD_MAP.fetch(sort[:field]))
            xml.poaSortOrder(SORT_ORDER_MAP.fetch(sort[:order]))
          end
        end
      end
    end
  end
end
