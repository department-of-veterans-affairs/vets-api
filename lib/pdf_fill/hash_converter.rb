# frozen_string_literal: true

require 'pdf_fill/form_value'

# frozen_string_literal: true
module PdfFill
  class HashConverter
    ITERATOR = '%iterator%'
    EXTRAS_TEXT = "See add'l info page"

    attr_reader :extras_generator

    def initialize(date_strftime, extras_generator)
      @pdftk_form = {}
      @date_strftime = date_strftime
      @extras_generator = extras_generator
    end

    def convert_value(v, key_data, is_overflow = false)
      if [true, false].include?(v) && !is_overflow
        v ? 1 : 0
      elsif key_data.try(:[], :format) == 'date'
        convert_val_as_date(v)
      else
        convert_val_as_string(v)
      end
    end

    def convert_val_as_string(v)
      case v
      when Array
        return v.map do |item|
          convert_val_as_string(item)
        end.join(', ')
      when PdfFill::FormValue
        return v
      end

      v.to_s
    end

    def convert_val_as_date(v)
      v = v.to_s

      date_split = v.split('-')
      date_args = Array.new(3) { |i| date_split[i].to_i }

      if Date.valid_date?(*date_args)
        Date.new(*date_args).strftime(@date_strftime)
      else
        convert_val_as_string(v)
      end
    end

    def overflow?(key_data, value, from_array_overflow = false)
      return false if value.blank? || from_array_overflow

      value = value.to_s if value.is_a?(Numeric)

      limit = key_data.try(:[], :limit)

      limit.present? && value.size > limit
    end

    def add_to_extras(key_data, v, i, top_level_key, overflow: true)
      return if v.blank? || key_data.nil?
      return if key_data[:question_num].blank? || key_data[:question_text].blank?

      i = nil if key_data[:skip_index]
      v = "$#{v}" if key_data[:dollar]
      v = v.extras_value if v.is_a?(PdfFill::FormValue)
      @extras_generator.add_text(
        v,
        key_data.slice(:question_num, :question_suffix, :question_text).merge(
          i:, top_level_key:, overflow:
        )
      )
    end

    def add_array_to_extras(arr, pdftk_keys, top_level_key)
      arr.each_with_index do |v, i|
        i = nil if pdftk_keys[:always_overflow]
        if v.is_a?(Hash)
          v.each do |key, val|
            add_to_extras(pdftk_keys[key], convert_value(val, pdftk_keys[key], true), i, top_level_key)
          end
        else
          add_to_extras(pdftk_keys, convert_value(v, pdftk_keys, true), i, top_level_key)
        end
      end
    end

    def set_value(v, key_data, i, from_array_overflow = false, top_level_key = nil)
      k = key_data[:key]
      return if k.blank?

      k = k.gsub(ITERATOR, i.to_s) unless i.nil?

      new_value = convert_value(v, key_data)

      if overflow?(key_data, new_value, from_array_overflow)
        add_to_extras(key_data, new_value, i, top_level_key)

        new_value = EXTRAS_TEXT
      elsif !from_array_overflow
        add_to_extras(key_data, new_value, i, top_level_key, overflow: false)
      end

      @pdftk_form[k] = new_value
    end

    def check_for_overflow(arr, pdftk_keys)
      return true if pdftk_keys[:always_overflow]
      return true if arr.size > (pdftk_keys[:limit] || 0)

      arr.each do |item|
        next if item.blank? || !item.is_a?(Hash)

        item.each do |k, v|
          return true if overflow?(pdftk_keys[k], v)
        end
      end

      false
    end

    def transform_array(form_data, pdftk_keys, top_level_key)
      has_overflow = check_for_overflow(form_data, pdftk_keys)

      if has_overflow
        first_key = pdftk_keys[:first_key]

        transform_data(
          form_data: { first_key => EXTRAS_TEXT },
          pdftk_keys:,
          i: 0,
          from_array_overflow: true,
          top_level_key:
        )

        add_array_to_extras(form_data, pdftk_keys, top_level_key)
      else
        form_data.each_with_index do |v, idx|
          transform_data(form_data: v, pdftk_keys:, i: idx, top_level_key:)
        end
      end
    end

    def transform_data(form_data:, pdftk_keys:, i: nil, from_array_overflow: false, top_level_key: nil)
      return if form_data.nil? || pdftk_keys.nil?

      case form_data
      when Array
        transform_array(form_data, pdftk_keys, top_level_key)
      when Hash
        form_data.each do |k, v|
          transform_data(
            form_data: v,
            pdftk_keys: pdftk_keys[k],
            i:,
            from_array_overflow:,
            top_level_key: top_level_key || k
          )
        end
      else
        set_value(form_data, pdftk_keys, i, from_array_overflow, top_level_key)
      end

      @pdftk_form
    end
  end
end
