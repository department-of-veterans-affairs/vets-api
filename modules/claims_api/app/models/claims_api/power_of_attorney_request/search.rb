# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    module Search
      module Query
        module Page
          # For the moment, these values duplicate the behavior of BGS.
          module Size
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

        class << self
          def dump(query, xml, data_aliaz)
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

        SORT_ORDER_MAP = {
          Query::Sort::Orders::ASCENDING => 'ASCENDING',
          Query::Sort::Orders::DESCENDING => 'DESCENDING'
        }.freeze

        SORT_FIELD_MAP = {
          Query::Sort::Fields::CREATED_AT => 'DATE_RECEIVED'
        }.freeze
      end

      class << self
        def perform(query) # rubocop:disable Metrics/MethodLength
          total_count = 0
          poa_requests = []

          begin
            action =
              BGSClient::Definitions::
                ManageRepresentativeService::
                ReadPoaRequest::
                DEFINITION

            response =
              BGSClient.perform_request(action) do |xml, data_aliaz|
                Query.dump(query, xml, data_aliaz)
              end

            total_count =
              response.dig(
                'POARequestRespondReturnVO',
                'totalNbrOfRecords'
              ).to_i

            poa_requests =
              Array.wrap(
                response.dig(
                  'POARequestRespondReturnVO',
                  'poaRequestRespondReturnVOList'
                )
              )

            poa_requests.map! do |data|
              Load.perform(data)
            end
          rescue BGSClient::Error::BGSFault => e
            # Sometimes this empty result is for valid reasons, i.e. a filter
            # combination that just happens to have no records. Other times it
            # is due to something like a non-existent POA code, which is an
            # invalid request from the client. But the BGS response looks the
            # same in either case so we can't distinguish between them.
            #
            # We could possibly make more requests to make that determination if
            # we find ourselves in this branch. But if we want to consider a
            # mixture of valid and invalid POA codes to be a valid request the
            # way BGS does, we'd have to check every POA code we were given.
            raise unless e.message == 'No Record Found'
          end

          [
            total_count,
            poa_requests
          ]
        end
      end
    end
  end
end
