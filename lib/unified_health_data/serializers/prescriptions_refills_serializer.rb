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

      # Initializes the serializer with prescription refill response data
      # @param id [String] Unique identifier for this refill transaction
      # @param resource [Hash] The refill response from UHD service with format:
      #   {
      #     success: [{ id: String, status: String, station_number: String }, ...],
      #     failed: [{ id: String, error: String, station_number: String }, ...]
      #   }
      def initialize(id, resource)
        failed_prescription_list = extract_failed_prescription_ids(resource)
        failed_station_list = extract_failed_station_numbers(resource)
        successful_prescription_list = resource[:success] || []
        successful_station_list = extract_successful_station_numbers(resource)
        last_updated_time = calculate_last_updated_time(resource)
        info_messages = build_info_messages(resource)
        errors = build_errors(resource)

        super(PrescriptionsRefillStruct.new(id, failed_station_list, successful_station_list,
                                            last_updated_time,
                                            successful_prescription_list, # prescription_list
                                            failed_prescription_list, errors, info_messages))
      end

      private

      def extract_failed_prescription_ids(resource)
        resource[:failed]&.map { |failed_item| failed_item[:id] } || []
      end

      def extract_failed_station_numbers(resource)
        resource[:failed]&.map { |failed_item| failed_item[:station_number] }&.uniq || []
      end

      def extract_successful_station_numbers(resource)
        resource[:success]&.map { |success_item| success_item[:station_number] }&.uniq || []
      end

      def calculate_last_updated_time(resource)
        Time.current.iso8601 if resource[:success]&.any? || resource[:failed]&.any?
      end

      def build_info_messages(resource)
        resource[:success]&.map do |success_item|
          {
            prescription_id: success_item[:id],
            message: success_item[:status] || 'Refill submitted successfully',
            station_number: success_item[:station_number]
          }
        end || []
      end

      def build_errors(resource)
        resource[:failed]&.map do |failed_item|
          prescription_id = failed_item[:id]
          last_four = prescription_id&.to_s&.last(4) || 'unknown'

          Rails.logger.warn(
            'Prescription refill failed',
            developer_message: failed_item[:error],
            prescription_id_last_four: last_four,
            station_number: failed_item[:station_number]
          )

          {
            developer_message: failed_item[:error],
            prescription_id: failed_item[:id],
            station_number: failed_item[:station_number]
          }
        end || []
      end
    end

    PrescriptionsRefillStruct = Struct.new(:id, :failed_station_list, :successful_station_list, :last_updated_time,
                                           :prescription_list,
                                           :failed_prescription_ids,
                                           :errors,
                                           :info_messages)
  end
end
