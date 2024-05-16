# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Helpers
      # A little debatable extracting this one.
      module XmlBuilder
        class << self
          def perform(service_action)
            aliaz = service_action.service_namespaces.keys.first

            builder =
              Nokogiri::XML::Builder.new(namespace_inheritance: false) do |xml|
                # Need to declare an arbitrary root element with placeholder
                # namespace in order to leverage namespaced tag building. The root
                # element itself is later ignored and only used for its contents.
                #   https://nokogiri.org/rdoc/Nokogiri/XML/Builder.html#method-i-5B-5D
                xml.root("xmlns:#{aliaz}" => 'placeholder') do
                  yield(xml, aliaz)
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
end
