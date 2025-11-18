# frozen_string_literal: true

module MyHealth
  module RxGroupingHelperV2
    def group_prescriptions(prescriptions)
      prescriptions ||= []
      grouped_prescriptions = []

      # Separate prescriptions with missing prescription numbers
      prescriptions_with_numbers, prescriptions_without_numbers = prescriptions.partition do |rx|
        rx.respond_to?(:prescription_number) && !rx.prescription_number.nil? && !rx.prescription_number.to_s.strip.empty?
      end

      prescriptions_with_numbers.sort_by!(&:prescription_number)

      while prescriptions_with_numbers.any?
        prescription = prescriptions_with_numbers[0]

        related_prescriptions = select_related_rxs(prescriptions_with_numbers, prescription)

        if related_prescriptions.length <= 1
          grouped_prescriptions << prescriptions_with_numbers.delete_at(0)
          next
        end

        base_prescription, related_prescriptions = find_base_prescription(related_prescriptions, prescription)
        
        related_prescriptions = sort_related_prescriptions(related_prescriptions)
        initialize_grouped_medications(base_prescription)
        add_group_meds_and_delete(related_prescriptions, base_prescription, prescriptions_with_numbers)

        grouped_prescriptions << base_prescription
        prescriptions_with_numbers.delete_at(prescriptions_with_numbers.index(base_prescription))
      end

      # Add prescriptions without prescription numbers at the end
      grouped_prescriptions + prescriptions_without_numbers
    end

    def get_single_rx_from_grouped_list(prescriptions, id)
      grouped_list = group_prescriptions(prescriptions)
      grouped_list.find { |rx| rx.prescription_id == id }
    end

    def count_grouped_prescriptions(prescriptions)
      return 0 if prescriptions.nil?

      prescriptions = prescriptions.dup
      count = 0

      # Separate prescriptions with missing prescription numbers
      prescriptions_with_numbers, prescriptions_without_numbers = prescriptions.partition do |rx|
        rx.respond_to?(:prescription_number) && !rx.prescription_number.nil? && !rx.prescription_number.to_s.strip.empty?
      end

      prescriptions_with_numbers.sort_by!(&:prescription_number)

      while prescriptions_with_numbers.any?
        prescription = prescriptions_with_numbers[0]
        related = select_related_rxs(prescriptions_with_numbers, prescription)

        if related.length <= 1
          count += 1
          prescriptions_with_numbers.delete_at(0)
          next
        end

        count += 1
        related.each { |rx| prescriptions_with_numbers.delete_at(prescriptions_with_numbers.index(rx)) }
      end

      # Add count for prescriptions without prescription numbers
      count + prescriptions_without_numbers.length
    end

    private

    def initialize_grouped_medications(prescription)
      prescription.grouped_medications ||= []
    end

    def add_solo_med_and_delete(grouped_prescriptions, prescriptions, prescription)
      grouped_prescriptions << prescription
      prescriptions.delete_at(0)
    end

    def add_group_meds_and_delete(related_prescriptions, base_prescription, prescriptions)
      related_prescriptions.each do |renewal|
        base_prescription.grouped_medications << renewal
        prescriptions.delete_at(prescriptions.index(renewal))
      end
    end

    def select_related_rxs(prescriptions, prescription)
      return [] unless prescription.respond_to?(:prescription_number) && prescription.prescription_number

      base_prescription_number = prescription.prescription_number.sub(/[A-Z]$/, '')

      prescriptions.select do |p|
        next false unless p.respond_to?(:prescription_number) && p.prescription_number

        current_prescription_number = p.prescription_number.sub(/[A-Z]$/, '')
        current_prescription_number == base_prescription_number && p.station_number == prescription.station_number
      end
    end

    def find_base_prescription(related_prescriptions, current_prescription)
      # related_prescriptions already includes all related items (including current_prescription)
      # from select_related_rxs, so don't add current_prescription again
      highest_prescription = related_prescriptions.max_by { |p| [p.prescription_number] }

      # Remove the highest from related_prescriptions to get remaining items to group under it
      remaining = related_prescriptions.reject { |p| p.prescription_id == highest_prescription.prescription_id }
      
      [highest_prescription, remaining]
    end

    def sort_related_prescriptions(related_prescriptions)
      related_prescriptions.sort do |rx1, rx2|
        suffix1 = rx1.prescription_number[/[A-Z]+$/] || ''
        suffix2 = rx2.prescription_number[/[A-Z]+$/] || ''

        if suffix1 == suffix2
          base_number1 = rx1.prescription_number.sub(/[A-Z]+$/, '').to_i
          base_number2 = rx2.prescription_number.sub(/[A-Z]+$/, '').to_i
          base_number1 <=> base_number2
        else
          suffix2 <=> suffix1
        end
      end
    end

    module_function :group_prescriptions
  end
end
