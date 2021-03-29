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

          groups[communication_group_id].communication_items << VAProfile::Models::CommunicationItem.new(
            id: communication_item['communication_item_id'],
            name: communication_item['common_name'],
            communication_channels: communication_item['communication_item_channels'].map do |communication_item_channel|
              communication_channel = communication_item_channel['communication_channel']

              communication_channel_model = VAProfile::Models::CommunicationChannel.new(
                id: communication_channel['communication_channel_id'],
                name: communication_channel['name'],
                description: communication_channel['description']
              )

              permission = permission_res['bios'].find do |permission|
                permission['communication_item_id'] == communication_item['communication_item_id'] &&
                  permission['communication_channel_id'] == communication_channel['communication_channel_id']
              end.tap do |permission|
                next if permission.nil?

                communication_channel_model.communication_permission = VAProfile::Models::CommunicationPermission.new(
                  id: permission['communication_permission_id'],
                  allowed: permission['allowed']
                )
              end

              communication_channel_model
            end
          )
        end

        groups.values
      end
    end
  end
end
