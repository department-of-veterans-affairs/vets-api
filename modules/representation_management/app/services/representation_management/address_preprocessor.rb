# frozen_string_literal: true

module RepresentationManagement
  module AddressPreprocessor
    PO_BOX_REGEX = /P\.?O\.?\s*BOX\s*\d+/i
    ROOM_SUITE_REGEX = /,?\s*(Room|Rm|Suite|Ste?)\.?\s*\d+/i

    module_function

    # Mutates a shallow copy of the address hash and returns it
    def clean(address)
      return address unless address.is_a?(Hash) && address['address_line1'].present?

      cleaned = address.dup
      line1 = cleaned['address_line1'].to_s.dup

      # Extract PO Box to address_line1
      if (m = line1.match(PO_BOX_REGEX))
        po = m.to_s.strip
        cleaned['address_line1'] = po
        cleaned['address_line2'] = nil
        return cleaned
      end

      # Extract suite/room to address_line2
      address_line, secondary_designator = extract_secondary_designator(line1)
      if address_line.blank?
        cleaned['address_line1'] = nil
        cleaned['address_line2'] = nil
        return cleaned
      end

      cleaned['address_line1'] = address_line
      cleaned['address_line2'] = cleaned['address_line2'].presence || secondary_designator

      cleaned
    end

    def extract_secondary_designator(line1)
      m = line1.match(ROOM_SUITE_REGEX)
      return [line1.strip, nil] unless m

      address_line = line1.sub(ROOM_SUITE_REGEX, '').strip
      secondary_designator = m.to_s.strip.sub(/^,\s*/, '')

      [address_line, secondary_designator]
    end
  end
end
