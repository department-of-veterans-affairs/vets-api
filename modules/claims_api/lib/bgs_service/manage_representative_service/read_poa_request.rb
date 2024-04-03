# frozen_string_literal: true

module ClaimsApi
  class ManageRepresentativeService < ClaimsApi::LocalBGS
    # rubocop:disable Metrics/MethodLength
    def read_poa_request(poa_codes: nil, statuses: nil)
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
          end
        end

      make_request(
        endpoint:,
        action: 'readPOARequest',
        body: builder.doc.at('root').children.to_xml,
        key: 'POARequestRespondReturnVO'
      )
    end
    # rubocop:enable Metrics/MethodLength
  end
end
