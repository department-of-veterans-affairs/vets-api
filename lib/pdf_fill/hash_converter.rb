# frozen_string_literal: true

require 'pdf_fill/form_value'

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

    def add_to_extras(key_data, v, i, overflow: true, array_key_data: nil)
      return if v.blank? || key_data.nil?
      return if key_data[:question_num].blank? || (key_data[:question_text].blank? && key_data[:question_label].blank?)

      i = array_key_data.try(:[], :override_index) || i
      i = nil if key_data[:skip_index]
      v = "$#{v}" if key_data[:dollar]
      v = v.extras_value if v.is_a?(PdfFill::FormValue)
      item_label = array_key_data.try(:[], :item_label)
      description_type = array_key_data.try(:[], :description_type)

      @extras_generator.add_text(
        v,
        key_data.slice(:question_num, :question_suffix, :question_text, :question_label, :question_type).merge(
          i:, overflow:, item_label:, description_type:
        )
      )
    end

    def add_array_to_extras(arr, pdftk_keys)
      arr.each_with_index do |v, i|
        i = nil if pdftk_keys[:always_overflow]
        if v.is_a?(Hash)
          v.each do |key, val|
            add_to_extras(pdftk_keys[key], convert_value(val, pdftk_keys[key], true), i, array_key_data: pdftk_keys)
          end
        else
          add_to_extras(pdftk_keys, convert_value(v, pdftk_keys, true), i, array_key_data: pdftk_keys)
        end
      end
    end

    def set_value(v, key_data, i, from_array_overflow = false)
      k = key_data[:key]
      return if k.blank?

      k = k.gsub(ITERATOR, i.to_s) unless i.nil?

      new_value = convert_value(v, key_data)

      if overflow?(key_data, new_value, from_array_overflow)
        add_to_extras(key_data, new_value, i)

        new_value = EXTRAS_TEXT
      elsif !from_array_overflow
        add_to_extras(key_data, new_value, i, overflow: false)
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

    def handle_overflow_and_label_all(form_data, pdftk_keys)
      form_data.each_with_index do |item, idx|
        item.each do |k, v|
          text = overflow?(pdftk_keys[k], v) ? EXTRAS_TEXT : v

          set_value(text, pdftk_keys[k], idx, true) if pdftk_keys[k].is_a?(Hash)
        end
      end
    end

    def handle_overflow_and_label_first_key(pdftk_keys)
      first_key = pdftk_keys[:first_key]
      transform_data(
        form_data: { first_key => EXTRAS_TEXT },
        pdftk_keys:,
        i: 0,
        from_array_overflow: true
      )
    end

    def transform_array(form_data, pdftk_keys)
      has_overflow = check_for_overflow(form_data, pdftk_keys)

      if has_overflow
        if pdftk_keys[:label_all]
          handle_overflow_and_label_all(form_data, pdftk_keys)
        else
          handle_overflow_and_label_first_key(pdftk_keys)
        end
        add_array_to_extras(form_data, pdftk_keys)
      else
        form_data.each_with_index do |v, idx|
          transform_data(form_data: v, pdftk_keys:, i: idx)
        end
      end
    end

    def transform_data(form_data:, pdftk_keys:, i: nil, from_array_overflow: false)
      return if form_data.nil? || pdftk_keys.nil?

      case form_data
      when Array
        transform_array(form_data, pdftk_keys)
      when Hash
        form_data.each do |k, v|
          transform_data(
            form_data: v,
            pdftk_keys: pdftk_keys[k],
            i:,
            from_array_overflow:
          )
        end
      else
        set_value(form_data, pdftk_keys, i, from_array_overflow)
      end

      @pdftk_form
    end
  end
end
