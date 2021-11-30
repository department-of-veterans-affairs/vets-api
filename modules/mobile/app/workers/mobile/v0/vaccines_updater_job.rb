# frozen_string_literal: true

module Mobile
  module V0
    # This job is run daily and pulls data from the CDC to create vaccine records
    class VaccinesUpdaterJob
      include Sidekiq::Worker
      sidekiq_options retry: 3

      GROUP_NAME_URL = 'https://www2.cdc.gov/vaccines/iis/iisstandards/XML.asp?rpt=vax2vg'
      MANUFACTURER_URL = 'https://www2a.cdc.gov/vaccines/iis/iisstandards/XML.asp?rpt=tradename'

      class VaccinesUpdaterError < StandardError; end

      # fetches group name and manufacturer data from the CDC and stores them in the vaccines table
      def perform
        logger.info('Updating vaccine records from CDC start')
        aggregate = {}
        results = { created: 0, updated: 0, persisted: 0 }

        group_name_xml.root.children.each do |node|
          aggregate_source_data(aggregate, node)
        end

        update_vaccine_records(aggregate, results)

        if (results[:created] + results[:updated] + results[:persisted]).zero?
          raise VaccinesUpdaterError, 'No records processed'
        end

        results.each_pair { |k, v| logger.info("#{k.capitalize} vaccine records: #{v}") }

        logger.info('Updating vaccine records from CDC end')
      end

      private

      def aggregate_source_data(aggregate, node)
        cvx_code = find_value(node, 'CVXCode')
        group_name = find_value(node, 'Vaccine Group Name')

        aggregate[cvx_code] = { group_names: [], manufacturer: nil } unless aggregate[cvx_code]
        aggregate[cvx_code][:group_names] << group_name
        aggregate[cvx_code][:manufacturer] = find_manufacturer(cvx_code) if group_name == 'COVID-19'
      end

      def update_vaccine_records(aggregate, results)
        aggregate.each_pair do |cvx_code, vaccine_data|
          vaccine = Mobile::V0::Vaccine.find_by(cvx_code: cvx_code)
          group_names = vaccine_data[:group_names].join(', ')

          unless vaccine
            Mobile::V0::Vaccine.create!(cvx_code: cvx_code, group_name: group_names,
                                        manufacturer: vaccine_data[:manufacturer])
            results[:created] += 1
            next
          end

          vaccine.group_name = group_names
          vaccine.manufacturer = vaccine_data[:manufacturer]
          if vaccine.changed?
            vaccine.save!
            results[:updated] += 1
          else
            results[:persisted] += 1
          end
        end
      end

      def group_name_xml
        @group_name_xml ||= Nokogiri::XML(URI.parse(GROUP_NAME_URL).open) do |config|
          config.strict.noblanks
        end
      end

      def manufacturer_xml
        @manufacturer_xml ||= Nokogiri::XML(URI.parse(MANUFACTURER_URL).open) do |config|
          config.strict.noblanks
        end
      end

      def find_value(node, property_name)
        node.children.each_slice(2) do |(name, value)|
          return value.text.strip if name.text.strip == property_name
        end
        raise VaccinesUpdaterError, "Property name #{property_name} not found"
      end

      def find_manufacturer(cvx_code)
        manufacturer_xml.root.children.each do |node|
          current_node_cvx = find_value(node, 'CVXCode')
          next unless current_node_cvx == cvx_code

          return find_value(node, 'Manufacturer')
        end
        nil
      end
    end
  end
end
