# frozen_string_literal: true

require_relative 'communication_base'
require_relative 'communication_item'

module VAProfile
  module Models
    class CommunicationItemGroup < CommunicationBase
      attr_accessor :name, :description, :communication_items

      def self.create_groups(items_res, permission_res)
        groups = {}

        items_res['bios'].each do |communication_item|
          communication_item_group = communication_item['communication_item_groups'][0]
          communication_group_id = communication_item_group['communication_group_id']

          groups[communication_group_id] ||= new(
            name: communication_item_group['communication_group']['name'],
            description: communication_item_group['communication_group']['description'],
            communication_items: []
          )

          groups[communication_group_id].communication_items <<
            VAProfile::Models::CommunicationItem.create_from_api(communication_item, permission_res)
        end

        groups.values
      end
    end
  end
end
