# frozen_string_literal: true

module MyHealth
  module RxGroupingHelperV2
    def group_prescriptions(prescriptions)
      prescriptions ||= []
      with_numbers, without_numbers = prescriptions.partition { |rx| valid_prescription_number?(rx) }
      grouped = process_prescriptions_with_numbers(with_numbers)
      grouped + without_numbers
    end

    def process_prescriptions_with_numbers(prescriptions_with_numbers)
      grouped_prescriptions = []
      prescriptions_with_numbers.sort_by!(&:prescription_number)

      while prescriptions_with_numbers.any?
        prescription = prescriptions_with_numbers[0]
        related_prescriptions = select_related_rxs(prescriptions_with_numbers, prescription)

        if related_prescriptions.length <= 1
          grouped_prescriptions << prescriptions_with_numbers.delete_at(0)
          next
        end

        group_related_prescriptions(related_prescriptions, prescription, prescriptions_with_numbers,
                                    grouped_prescriptions)
      end

      grouped_prescriptions
    end

    def group_related_prescriptions(related_prescriptions, prescription, prescriptions_with_numbers,
                                    grouped_prescriptions)
      base_prescription, related_prescriptions = find_base_prescription(related_prescriptions, prescription)
      related_prescriptions = sort_related_prescriptions(related_prescriptions)
      initialize_grouped_medications(base_prescription)
      add_group_meds_and_delete(related_prescriptions, base_prescription, prescriptions_with_numbers)
      grouped_prescriptions << base_prescription
      prescriptions_with_numbers.delete_at(prescriptions_with_numbers.index(base_prescription))
    end

    def get_single_rx_from_grouped_list(prescriptions, id)
      grouped_list = group_prescriptions(prescriptions)
      grouped_list.find { |rx| rx.prescription_id == id }
    end

    def count_grouped_prescriptions(prescriptions)
      return 0 if prescriptions.nil?

      with_numbers, without_numbers = prescriptions.dup.partition { |rx| valid_prescription_number?(rx) }
      count_prescriptions_with_numbers(with_numbers) + without_numbers.length
    end

    def count_prescriptions_with_numbers(prescriptions_with_numbers)
      count = 0
      prescriptions_with_numbers.sort_by!(&:prescription_number)

      while prescriptions_with_numbers.any?
        prescription = prescriptions_with_numbers[0]
        related = select_related_rxs(prescriptions_with_numbers, prescription)
        count += 1
        remove_processed_prescriptions(related, prescriptions_with_numbers)
      end

      count
    end

    def remove_processed_prescriptions(related, prescriptions_with_numbers)
      if related.length <= 1
        prescriptions_with_numbers.delete_at(0)
      else
        related.each { |rx| prescriptions_with_numbers.delete_at(prescriptions_with_numbers.index(rx)) }
      end
    end

    private

    def valid_prescription_number?(rx)
      rx.respond_to?(:prescription_number) && rx.prescription_number && !rx.prescription_number.to_s.strip.empty?
    end

    def initialize_grouped_medications(prescription)
      prescription.grouped_medications ||= []
    end

    def add_solo_med_and_delete(grouped_prescriptions, prescriptions, _prescription)
      grouped_prescriptions << prescriptions.delete_at(0)
    end

    def add_group_meds_and_delete(related_prescriptions, base_prescription, prescriptions)
      related_prescriptions.each do |renewal|
        base_prescription.grouped_medications << renewal
        prescriptions.delete_at(prescriptions.index(renewal))
      end
    end

    def select_related_rxs(prescriptions, prescription)
      return [] unless prescription.respond_to?(:prescription_number) && prescription.prescription_number

      base_number = prescription.prescription_number.sub(/[A-Z]$/, '')
      prescriptions.select do |p|
        p.respond_to?(:prescription_number) && p.prescription_number &&
          p.prescription_number.sub(/[A-Z]$/, '') == base_number &&
          p.station_number == prescription.station_number
      end
    end

    def find_base_prescription(related_prescriptions, _current_prescription)
      highest = related_prescriptions.max_by { |p| [p.prescription_number] }
      remaining = related_prescriptions.reject { |p| p.prescription_id == highest.prescription_id }
      [highest, remaining]
    end

    def sort_related_prescriptions(related_prescriptions)
      related_prescriptions.sort do |rx1, rx2|
        compare_prescription_numbers(rx1.prescription_number, rx2.prescription_number)
      end
    end

    def compare_prescription_numbers(num1, num2)
      s1 = num1[/[A-Z]+$/] || ''
      s2 = num2[/[A-Z]+$/] || ''
      s1 == s2 ? num1.sub(/[A-Z]+$/, '').to_i <=> num2.sub(/[A-Z]+$/, '').to_i : s2 <=> s1
    end

    module_function :group_prescriptions
  end
end
