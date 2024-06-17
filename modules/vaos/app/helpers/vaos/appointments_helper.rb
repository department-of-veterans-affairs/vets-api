# frozen_string_literal: true

module VAOS
  module AppointmentsHelper
    # Checks if the appointment is associated with cerner. It looks through each identifier and checks if the system
    # contains cerner. If it does, it returns true. Otherwise, it returns false.
    #
    # @param appt [Hash] the appointment to check
    # @return [Boolean] true if the appointment is associated with cerner, false otherwise
    #
    # @raise [ArgumentError] if the appointment is nil
    def self.cerner?(appt)
      raise ArgumentError, 'Appointment cannot be nil' if appt.nil?

      identifiers = appt[:identifier]

      return false if identifiers.nil?

      identifiers.each do |identifier|
        system = identifier[:system]
        return true if system.include?('cerner')
      end

      false
    end

    # This method extracts all values from a given object, which can be either an `OpenStruct`, `Hash`, or `Array`.
    # It recursively traverses the object and collects all values into an array.
    # In case of an `Array`, it looks inside each element of the array for values.
    # If the object is neither an OpenStruct, Hash, nor an Array, it returns the unmodified object in an array.
    #
    # @param object [OpenStruct, Hash, Array] The object from which to extract values.
    # This could either be an OpenStruct, Hash or Array.
    #
    # @return [Array] An array of all values found in the object.
    # If the object is not an OpenStruct, Hash, nor an Array, then the unmodified object is returned.
    #
    # @example
    #   extract_all_values({a: 1, b: 2, c: {d: 3, e: 4}})  # => [1, 2, 3, 4]
    #   extract_all_values(OpenStruct.new(a: 1, b: 2, c: OpenStruct.new(d: 3, e: 4))) # => [1, 2, 3, 4]
    #   extract_all_values([{a: 1}, {b: 2}]) # => [1, 2]
    #   extract_all_values({a: 1, b: [{c: 2}, {d: "hello"}]}) # => [1, 2, "hello"]
    #   extract_all_values("not a hash, openstruct, or array")  # => ["not a hash, openstruct, or array"]
    #
    def self.extract_all_values(object)
      return [object] unless object.is_a?(OpenStruct) || object.is_a?(Hash) || object.is_a?(Array)

      values = []
      object = object.to_h if object.is_a?(OpenStruct)

      if object.is_a?(Array)
        object.each do |o|
          values += extract_all_values(o)
        end
      else
        object.each_pair do |_, value|
          case value
          when OpenStruct, Hash, Array then values += extract_all_values(value)
          else values << value
          end
        end
      end

      values
    end

    # This method checks if any string element in the given array contains the specified substring.
    #
    # @param arr [Array] The array to be searched.
    # @param substring [String] The substring to look for.
    #
    # @return [Boolean] Returns true if any string element in the array contains the substring, false otherwise.
    # If the input parameters are not of the correct type the method will return false.
    #
    # @example
    #   contains_substring?(['Hello', 'World'], 'ell')  # => true
    #   contains_substring?(['Hello', 'World'], 'xyz')  # => false
    #   contains_substring?('Hello', 'ell')  # => false
    #   contains_substring?(['Hello', 'World'], 123)  # => false
    #
    def self.contains_substring?(arr, substring)
      return false unless arr.is_a?(Array) && substring.is_a?(String)

      arr.any? { |element| element.is_a?(String) && element.include?(substring) }
    end

    def self.log_appt_id_location_name(appt)
      return unless cerner?(appt)

      location_values = extract_all_values(appt[:location])
      return unless contains_substring?(location_values, 'COL OR 1')

      Rails.logger.info("Details for Cerner 'COL OR 1' Appointment", {
        appt_id: appt[:id],
        facility_location_id: appt[:location]&.[]('id'),
        facility_name: appt[:location]&.[]('name')
      }.to_json)
    end
  end
end
