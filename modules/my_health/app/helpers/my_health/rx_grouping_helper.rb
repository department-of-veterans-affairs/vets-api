# frozen_string_literal: true

module MyHealth
  module RxGroupingHelper
    def group_prescriptions(prescriptions)
      prescriptions ||= []
      grouped_prescriptions = []

      prescriptions.sort_by!(&:prescription_number)

      while prescriptions.any?
        prescription = prescriptions[0]

        related_prescriptions = select_related_rxs(prescriptions, prescription)

        if related_prescriptions.length <= 1
          add_solo_med_and_delete(grouped_prescriptions, prescriptions, prescription)
          next
        end

        base_prescription, related_prescriptions = find_base_prescription(related_prescriptions, prescription)
        related_prescriptions = sort_related_prescriptions(related_prescriptions)
        base_prescription.grouped_medications ||= []
        add_group_meds_and_delete(related_prescriptions, base_prescription, prescriptions)

        grouped_prescriptions << base_prescription
        prescriptions.delete(base_prescription)
      end

      grouped_prescriptions
    end

    def get_single_rx_from_grouped_list(prescriptions, id)
      grouped_list = group_prescriptions(prescriptions)
      grouped_list.find { |rx| rx.prescription_id == id }
    end

    def count_grouped_prescriptions(prescriptions)
      return 0 if prescriptions.nil?

      # Create a duplicate to avoid modifying the original array
      # This is more efficient than the caller keeping a full copy just for this count
      prescriptions = prescriptions.dup
      count = 0

      prescriptions.sort_by!(&:prescription_number)

      while prescriptions.any?
        prescription = prescriptions[0]
        related = select_related_rxs(prescriptions, prescription)

        if related.length <= 1
          count += 1
          prescriptions.delete(prescription)
          next
        end

        count += 1
        related.each { |rx| prescriptions.delete(rx) }
      end

      count
    end

    private

    def add_solo_med_and_delete(grouped_prescriptions, prescriptions, prescription)
      grouped_prescriptions << prescription
      prescriptions.delete(prescription)
    end

    def add_group_meds_and_delete(related_prescriptions, base_prescription, prescriptions)
      related_prescriptions.each do |renewal|
        base_prescription.grouped_medications << renewal
        prescriptions.delete(renewal)
      end
    end

    def select_related_rxs(prescriptions, prescription)
      prescriptions.select do |p|
        base_prescription = prescription.prescription_number.sub(/[A-Z]$/, '')
        current_prescription_number = p.prescription_number.sub(/[A-Z]$/, '')
        current_prescription_number == base_prescription && p.station_number == prescription.station_number
      end
    end

    def find_base_prescription(related_prescriptions, current_prescription)
      all_prescriptions = [current_prescription] + related_prescriptions
      highest_prescription = all_prescriptions.max_by { |p| [p.prescription_number] }

      related_prescriptions.delete(highest_prescription)
      [highest_prescription, related_prescriptions]
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
