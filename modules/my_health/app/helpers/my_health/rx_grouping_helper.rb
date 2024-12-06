# frozen_string_literal: true

module MyHealth
  module RxGroupingHelper
    def group_prescriptions(prescriptions)
      grouped_prescriptions = []

      while prescriptions.any?
        prescription = prescriptions.shift
        base_prescription_number = prescription.prescription_number.sub(/[A-Z]$/, '')

        related_prescriptions = prescriptions.select do |p|
          p.prescription_number.sub(/[A-Z]$/,
                                    '') == base_prescription_number && p.station_number == prescription.station_number
        end
        related_prescriptions += [prescription]
        if related_prescriptions.length <= 1
          puts "Added solo prescription: #{prescription.prescription_number}"
          grouped_prescriptions << prescription
          next
        end

        # puts "Related prescriptions: #{related_prescriptions.map { |rx| rx.prescription_number }.join(', ')}"
        # puts "Original prescription: #{prescription.prescription_number}"
        base_prescription, related_prescriptions = find_base_prescription(related_prescriptions, prescription)

        base_prescription.grouped_medications ||= []
        related_prescriptions.each do |renewal|
          base_prescription.grouped_medications << renewal
          prescriptions.delete(renewal)
          # puts "Grouped Renewal: #{renewal.prescription_number} under #{base_prescription.prescription_number}"
        end
        grouped_prescriptions << base_prescription
        # puts "Added #{base_prescription.prescription_number} to grouped_prescriptions"
        # puts '_______________________________________________________________________'
      end
      grouped_prescriptions
    end

    private

    def find_base_prescription(related_prescriptions, current_prescription)
      all_prescriptions = [current_prescription] + related_prescriptions
      highest_prescription = all_prescriptions.max_by { |p| [p.prescription_number, p.ordered_date || Time.at(0)] }

      related_prescriptions.delete(highest_prescription)

      # puts "Found base prescription: #{highest_prescription.prescription_number}"
      # puts "Remaining related prescriptions: #{related_prescriptions.map { |rx| rx.prescription_number }.join(', ')}"

      [highest_prescription, related_prescriptions]
    end

    module_function :group_prescriptions
  end
end
