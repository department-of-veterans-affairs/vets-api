# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Search
      class Query
        class << self
          def build!(...)
            new(...).build!
          end
        end

        def initialize(poa_codes:, statuses:)
          @statuses = statuses
          @poa_codes = poa_codes
          @page = {}
        end

        def build!
          validate!
          dump
        end

        private
        
        def validate!
          # TODO: implement
        end

        def dump
          builder =
            Nokogiri::XML::Builder.new(namespace_inheritance: false) do |xml|
              # Need to declare an arbitrary root element with placeholder
              # namespace in order to leverage namespaced tag building. The root
              # element itself is later ignored and only used for its contents.
              #   https://nokogiri.org/rdoc/Nokogiri/XML/Builder.html#method-i-5B-5D
              xml.root('xmlns:data' => 'placeholder') do
                if @statuses
                  xml['data'].SecondaryStatusList do
                    @statuses.each do |status|
                      xml.SecondaryStatus(status)
                    end
                  end
                end

                if @poa_codes
                  xml['data'].POACodeList do
                    @poa_codes.each do |poa_code|
                      xml.POACode(poa_code)
                    end
                  end
                end

                if @page.present?
                  xml['data'].POARequestParameter do
                    xml.pageIndex(@page[:index])
                    xml.pageSize(@page[:size])
                  end
                end
              end
            end

          builder
            .doc.at('root')
            .children
            .to_xml
        end
      end
    end
  end
end


