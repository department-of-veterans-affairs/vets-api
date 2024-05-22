# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Search
      class InvalidQueryError < StandardError
        attr_reader :errors, :params

        def initialize(errors, params)
          @errors = errors
          @params = params
          super()
        end
      end

      class << self
        def perform(params) # rubocop:disable Metrics/MethodLength
          # This ensures that our data is totally valid. If not, it raises. If
          # it is valid, it gives back a query object with defaults filled out
          # that we can then show back to the client as metadata.
          query = Query.compile!(params)

          total_count = 0
          data = []

          begin
            response = perform_request(query)
            result = response['POARequestRespondReturnVO'].to_h
            total_count = result['totalNbrOfRecords'].to_i

            data = result['poaRequestRespondReturnVOList']
            data = Array.wrap(data).map! do |datum|
              # TODO: Rework hydration into `PoaRequest` and possibly collocate
              # here with the rest of the dump/load code?
              PoaRequest.load(datum)
            end
          rescue BGSClient::Error::BGSFault => e
            # Sometimes this empty result is for valid reasons, i.e. a filter
            # combo that just happens to have no records. Other times it is due
            # to something like a non-existent POA code, which is an invalid
            # request from the client. But the BGS response looks the same in
            # either case so we can't distinguish between them.
            raise unless e.message == 'No Record Found'
          end

          {
            metadata: {
              totalCount: total_count,
              query:
            },
            data:
          }
        end

        private

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
              xml.poaSortField(Sort::FIELDS.fetch(sort[:field]))
              xml.poaSortOrder(Sort::ORDERS.fetch(sort[:order]))
            end
          end
        end
      end

      module Sort
        ORDERS = {
          Query::Sort::Orders::ASCENDING => 'ASCENDING',
          Query::Sort::Orders::DESCENDING => 'DESCENDING'
        }.freeze

        FIELDS = {
          Query::Sort::Fields::CREATED_AT => 'DATE_RECEIVED'
        }.freeze
      end
    end
  end
end
