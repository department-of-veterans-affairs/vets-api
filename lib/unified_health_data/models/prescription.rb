# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class Prescription
    include Vets::Model

    attribute :id, String
    attribute :type, String
    attribute :refill_status, String
    attribute :refill_submit_date, String
    attribute :refill_date, String
    attribute :refill_remaining, Integer
    attribute :facility_name, String
    attribute :ordered_date, String
    attribute :quantity, String
    attribute :expiration_date, String
    attribute :prescription_number, String
    attribute :prescription_name, String
    attribute :dispensed_date, String
    attribute :station_number, String
    attribute :is_refillable, Bool
    attribute :is_trackable, Bool
    attribute :tracking, Array, default: []
    attribute :instructions, String
    attribute :facility_phone_number, String
    attribute :cmop_division_phone, String
    attribute :dial_cmop_division_phone, String
    attribute :prescription_source, String
    attribute :category, Array, default: []
    attribute :dispenses, Array, default: []
    attribute :disclaimer, String
    attribute :provider_name, String
    attribute :indication_for_use, String
    attribute :remarks, String
    attribute :cmop_ndc_number, String
    attribute :grouped_medications, Array, default: nil
    attribute :disp_status, String
    attribute :task_resources, Array, default: []

    # Method aliases to match serializer expectations
    def prescription_id
      id
    end

    # Checks if a prescription originated from Oracle Health system
    # Oracle Health prescriptions lack refill_submit_date (not in FHIR standard)
    def oracle_health_prescription?
      refill_submit_date.nil? && prescription_source == 'VA'
    end

    # Extracts refill submission metadata from Oracle Health Task resources
    # Task resources contain refill request information per FHIR standard
    # This provides timing information to help users understand refill processing status
    #
    # @return [Hash] Hash containing refill metadata from Task resources
    def refill_metadata_from_tasks
      metadata = {}

      # Look for Task resources in the prescription's contained resources
      # Task.status indicates the refill request outcome (requested, in-progress, completed, failed, etc.)
      # Task.executionPeriod.start indicates when the refill request was submitted
      return metadata unless task_resources.present?

      # Find the most recent refill request task
      refill_tasks = task_resources.select { |task| task[:status].present? }
      return metadata unless refill_tasks.any?

      # Sort by executionPeriod.start to find most recent submission
      most_recent_task = refill_tasks.max_by do |task|
        if task[:execution_period_start]
          begin
            Time.zone.parse(task[:execution_period_start])
          rescue ArgumentError
            Time.zone.at(0)
          end
        else
          Time.zone.at(0)
        end
      end

      return metadata unless most_recent_task

      # Extract submission timestamp from executionPeriod.start
      if most_recent_task[:execution_period_start]
        metadata[:refill_submit_date] = most_recent_task[:execution_period_start]

        # Calculate days since submission for frontend display
        begin
          submit_time = Time.zone.parse(most_recent_task[:execution_period_start])
          if submit_time
            days_since = ((Time.zone.now - submit_time) / 1.day).floor
            metadata[:days_since_submission] = days_since if days_since >= 0
          end
        rescue ArgumentError, TypeError
          # Invalid date format, skip calculation
        end
      end

      # Extract refill request status from Task.status
      metadata[:refill_request_status] = most_recent_task[:status] if most_recent_task[:status]

      # Include other relevant task fields if available
      metadata[:task_id] = most_recent_task[:id] if most_recent_task[:id]

      metadata
    end
  end
end
