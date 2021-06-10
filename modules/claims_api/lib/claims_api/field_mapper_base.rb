# frozen_string_literal: true

module ClaimsApi
  class FieldMapperBase
    # Convert to name from code of item.
    #
    # @param code [String] Short code of item
    # @return [String] Verbose name of item
    def name_from_code!(code)
      from_code(code)[:name]
    end

    def name_from_code(code)
      name_from_code!(code)
    rescue
      nil
    end

    # Convert to code from name of item.
    #
    # @param name [String] Verbose name of item
    # @return [String] Short code of item
    def code_from_name!(name)
      from_name(name)[:code]
    end

    def code_from_name(name)
      code_from_name!(name)
    rescue
      nil
    end

    protected

    def items
      raise 'NotImplemented'
    end

    def from_code(code)
      item = items.find { |si| si[:code] == code }
      raise ::Common::Exceptions::InvalidFieldValue.new('item', code) if item.blank?

      item
    end

    def from_name(name)
      item = items.find { |si| si[:name] == name }
      raise ::Common::Exceptions::InvalidFieldValue.new('item', name) if item.blank?

      item
    end
  end
end
