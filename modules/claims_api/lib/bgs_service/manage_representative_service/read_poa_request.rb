# frozen_string_literal: true

module ClaimsApi
  module ManageRepresentativeService
    # TODO: Figure out input and output massaging.
    # TODO: Figure out how to get back error intepretation flexibility.
    module ReadPoaRequest
      DEFAULT_PAGE_SIZSE = 25
      MAX_PAGE_SIZSE = 100

      class << self
        def call(poa_codes: nil, statuses: nil, page: {})
          builder =
            Nokogiri::XML::Builder.new(namespace_inheritance: false) do |xml|
              # Need to declare an arbitrary root element with placeholder
              # namespace in order to leverage namespaced tag building. The root
              # element itself is later ignored and only used for its contents.
              #   https://nokogiri.org/rdoc/Nokogiri/XML/Builder.html#method-i-5B-5D
              xml.root('xmlns:data' => 'placeholder') do
                if statuses
                  xml['data'].SecondaryStatusList do
                    statuses.each do |status|
                      xml.SecondaryStatus(status)
                    end
                  end
                end

                if poa_codes
                  xml['data'].POACodeList do
                    poa_codes.each do |poa_code|
                      xml.POACode(poa_code)
                    end
                  end
                end

                if page.present?
                  xml['data'].POARequestParameter do
                    xml.pageIndex(page[:index])
                    xml.pageSize(page[:size])
                  end
                end
              end
            end

          ManageRepresentativeService.call(
            action: 'readPOARequest',
            body: builder.doc.at('root').children.to_xml,
            key: 'POARequestRespondReturnVO'
          )
        end
      end
    end
  end
end
