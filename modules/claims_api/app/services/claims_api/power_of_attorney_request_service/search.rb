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
            body = dump_query(query)
            response = perform_request(body)

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

        # Check https://github.com/department-of-veterans-affairs/bgs-catalog for:
        #   `VDC/ManageRepresentativeService/ManageRepresentativePortBinding/readPOARequest/request.xml`
        def perform_request(body)
          service_action =
            BGSClient::ServiceAction::
              ManageRepresentativeService::
              ReadPoaRequest

          BGSClient.perform_request(
            service_action:,
            body:
          )
        end

        def dump_query(query) # rubocop:disable Metrics/MethodLength
          builder =
            Nokogiri::XML::Builder.new(namespace_inheritance: false) do |xml|
              # Need to declare an arbitrary root element with placeholder
              # namespace in order to leverage namespaced tag building. The root
              # element itself is later ignored and only used for its contents.
              #   https://nokogiri.org/rdoc/Nokogiri/XML/Builder.html#method-i-5B-5D
              xml.root('xmlns:data' => 'placeholder') do
                filter = query[:filter]

                xml['data'].SecondaryStatusList do
                  filter[:statuses].each do |status|
                    xml.SecondaryStatus(status)
                  end
                end

                xml['data'].POACodeList do
                  filter[:poaCodes].each do |poa_code|
                    xml.POACode(poa_code)
                  end
                end

                xml['data'].POARequestParameter do
                  page = query[:page]
                  xml.pageIndex(page[:number])
                  xml.pageSize(page[:size])

                  sort = query[:sort]
                  xml.poaSortField(Sort::FIELDS.fetch(sort[:field]))
                  xml.poaSortOrder(Sort::ORDERS.fetch(sort[:order]))
                end
              end
            end

          builder
            .doc.at('root')
            .children
            .to_xml
        end
      end

      module Sort
        ORDERS = {
          Query::Sort::Orders::ASCENDING => 'ASCENDING',
          Query::Sort::Orders::DESCENDING => 'DESCENDING'
        }.freeze

        FIELDS = {
          Query::Sort::Fields::SUBMITTED_AT => 'DATE_RECEIVED'
        }.freeze
      end
    end
  end
end
