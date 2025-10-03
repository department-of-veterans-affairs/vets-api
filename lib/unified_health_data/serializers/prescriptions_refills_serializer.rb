# frozen_string_literal: true

module UnifiedHealthData
  module Serializers
    class PrescriptionsRefillsSerializer
      include JSONAPI::Serializer

      set_type :PrescriptionRefills

      attributes :failed_station_list,
                 :successful_station_list,
                 :last_updated_time,
                 :prescription_list,
                 :failed_prescription_ids,
                 :errors,
                 :info_messages

      def initialize(id, resource)
        # Extract failed prescription IDs from the new format
        failed_prescription_list = resource[:failed]&.map do |failed_item|
          failed_item[:id]
        end || []

        # Extract station numbers from failed items
        failed_station_list = resource[:failed]&.map do |failed_item|
          failed_item[:station_number]
        end&.uniq || []

        # Extract successful prescription IDs
        successful_prescription_list = resource[:success] || []

        # Extract station numbers from successful items
        successful_station_list = resource[:success]&.map do |success_item|
          success_item[:station_number]
        end&.uniq || []

        # Set last_updated_time to current time when there are any results
        last_updated_time = if resource[:success]&.any? || resource[:failed]&.any?
                              Time.current.iso8601
                            end

        # Collect info messages from successful refills
        info_messages = resource[:success]&.map do |success_item|
          {
            prescription_id: success_item[:id],
            message: success_item[:status] || 'Refill submitted successfully',
            station_number: success_item[:station_number]
          }
        end || []

        # Convert failed items to error format for backwards compatibility
        errors = resource[:failed]&.map do |failed_item|
          {
            developer_message: failed_item[:error],
            prescription_id: failed_item[:id],
            station_number: failed_item[:station_number]
          }
        end || []

        super(PrescriptionsRefillStruct.new(id, failed_station_list, successful_station_list,
                                            last_updated_time,
                                            successful_prescription_list, # prescription_list
                                            failed_prescription_list, errors, info_messages))
      end
    end

    PrescriptionsRefillStruct = Struct.new(:id, :failed_station_list, :successful_station_list, :last_updated_time,
                                           :prescription_list,
                                           :failed_prescription_ids,
                                           :errors,
                                           :info_messages)
  end
end
