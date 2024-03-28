# frozen_string_literal: true

module ClaimsApi
  class ManageRepresentativeService < ClaimsApi::LocalBGS
    def read_poa_request(poa_codes: nil, statuses: nil)
      builder =
        Nokogiri::XML::Builder.new(namespace_inheritance: false) do |xml|
          # Need to declare an arbitrary root element with placeholder
          # namespace in order to leverage namespaced tag building. The root
          # element is later ignored and only used for its contents.
          #   https://nokogiri.org/rdoc/Nokogiri/XML/Builder.html#method-i-5B-5D
          xml.root('xmlns:data' => 'placeholder') {
            if statuses
              xml['data'].SecondaryStatusList {
                statuses.each do |status|
                  xml.SecondaryStatus(status)
                end
              }
            end

            if poa_codes
              xml['data'].POACodeList {
                poa_codes.each { |poa_code|
                  xml.POACode(poa_code)
                }
              }
            end
          }
        end

      make_request(
        endpoint: 'VDC/ManageRepresentativeService',
        action: 'readPOARequest',
        body: builder.doc.at('root').children.to_xml,
        key: 'POARequestRespondReturnVO',
      )
    end
  end
end
