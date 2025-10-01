# frozen_string_literal: true

module Veteran
  module AddressPreprocessor
    PO_BOX_REGEX = /P\.?O\.?\s*BOX\s*\d+/i.freeze
    ROOM_SUITE_REGEX = /,?\s*(Room|Rm|Suite|Ste?)\.?\s*\d+/i.freeze

    module_function

    # Mutates a shallow copy of the address hash and returns it
    def clean(address)
      return address unless address.is_a?(Hash) && address['address_line1'].present?

      cleaned = address.dup
      line1 = cleaned['address_line1'].to_s.dup

      # Extract suite/room to address_line2
      if (m = line1.match(ROOM_SUITE_REGEX))
        cleaned['address_line1'] = line1.sub(ROOM_SUITE_REGEX, '').strip
        line2 = m.to_s.strip.sub(/^,\s*/, '')
        cleaned['address_line2'] = (cleaned['address_line2'].presence || line2)
      end

      # Extract PO Box to address_line1, move prefix to address_line2 if present
      if (m = line1.match(PO_BOX_REGEX))
        po = m.to_s.strip
        prefix = line1.sub(PO_BOX_REGEX, '').strip
        cleaned['address_line1'] = po
        cleaned['address_line2'] = cleaned['address_line2'].presence || (prefix.presence)
      end

      cleaned
    end
  end
end
