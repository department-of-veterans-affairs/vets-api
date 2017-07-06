require 'pdf_fill/extras_generator'

# frozen_string_literal: true
module PdfFill
  class HashConverter
    ITERATOR = '%iterator%'
    EXTRAS_TEXT = "See add'l info page"

    attr_reader :extras_generator

    def initialize(date_strftime)
      @pdftk_form = {}
      @date_strftime = date_strftime
      @extras_generator = ExtrasGenerator.new
    end

    def convert_value(v)
      if [true, false].include?(v)
        v ? 1 : 0
      else
        convert_val_as_string(v)
      end
    end

    def convert_val_as_string(v)
      if v.is_a?(Array)
        return v.map do |item|
          convert_val_as_string(item)
        end.join(', ')
      end

      v = v.to_s

      date_split = v.split('-')
      date_args = Array.new(3) { |i| date_split[i].to_i }

      if Date.valid_date?(*date_args)
        Date.new(*date_args).strftime(@date_strftime)
      else
        v
      end
    end

    def overflow?(key_data, value)
      value = value.to_s if value.is_a?(Numeric)

      limit = key_data.try(:[], :limit)

      limit.present? && value.size > limit
    end

    def add_to_extras(key_data, v, i)
      return if v.blank?
      text_prefix = key_data.try(:[], :question)
      return if text_prefix.blank?

      text_prefix += " Line #{i + 1}" if i.present?

      @extras_generator.add_text(text_prefix, v)
    end

    def add_array_to_extras(arr, pdftk_keys)
      arr.each_with_index do |v, i|
        i = nil if pdftk_keys[:always_overflow]

        if v.is_a?(Hash)
          v.each do |key, val|
            add_to_extras(pdftk_keys[key], convert_val_as_string(val), i)
          end
        else
          add_to_extras(pdftk_keys, convert_val_as_string(v), i)
        end
      end
    end

    def set_value(v, key_data, i)
      k = key_data[:key]
      return if k.blank?
      k = k.gsub(ITERATOR, i.to_s) unless i.nil?

      new_value = convert_value(v)

      if overflow?(key_data, new_value)
        add_to_extras(key_data, new_value, i)

        new_value = EXTRAS_TEXT
      end

      @pdftk_form[k] = new_value
    end

    def check_for_overflow(arr, pdftk_keys)
      return true if pdftk_keys[:always_overflow]
      return true if arr.size > pdftk_keys[:limit]

      arr.each do |item|
        next if item.blank? || !item.is_a?(Hash)

        item.each do |k, v|
          return true if overflow?(pdftk_keys[k], v)
        end
      end

      false
    end

    def transform_array(form_data, pdftk_keys)
      has_overflow = check_for_overflow(form_data, pdftk_keys)

      if has_overflow
        first_key = pdftk_keys[:first_key]

        transform_data(
          form_data: { first_key => EXTRAS_TEXT },
          pdftk_keys: pdftk_keys,
          i: 0
        )

        add_array_to_extras(form_data, pdftk_keys)
      else
        form_data.each_with_index do |v, idx|
          transform_data(form_data: v, pdftk_keys: pdftk_keys, i: idx)
        end
      end
    end

    def transform_data(form_data:, pdftk_keys:, i: nil)
      return if form_data.nil? || pdftk_keys.nil?

      case form_data
      when Array
        transform_array(form_data, pdftk_keys)
      when Hash
        form_data.each do |k, v|
          transform_data(
            form_data: v,
            pdftk_keys: pdftk_keys[k],
            i: i
          )
        end
      else
        set_value(form_data, pdftk_keys, i)
      end

      @pdftk_form
    end
  end
end
