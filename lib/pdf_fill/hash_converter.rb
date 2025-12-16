# frozen_string_literal: true

require 'pdf_fill/form_value'

module PdfFill
  class HashConverter
    ITERATOR = '%iterator%'

    attr_reader :extras_generator

    delegate :placeholder_text, to: :extras_generator

    def initialize(date_strftime, extras_generator)
      @pdftk_form = {}
      @date_strftime = date_strftime
      @extras_generator = extras_generator
      @use_hexapdf = extras_generator.use_hexapdf
    end

    def convert_value(v, key_data, is_overflow = false)
      if [true, false].include?(v) && !is_overflow
        v ? 1 : 0
      elsif key_data.try(:[], :format) == 'date'
        convert_val_as_date(v)
      elsif v == 'Off' && @extras_generator.use_hexapdf
        # HexaPDF accepts a certain set of values for checkboxes, one of them being
        # false, but it converts that value to 'Off' when filling the PDF. This conversion
        # allows us to maintain interoperability with HexaPDF (uses false) and PDFtk (uses 'Off')
        false
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

    def format_currency(v)
      v = v.to_s.gsub('$', '').gsub(',', '')

      ActiveSupport::NumberHelper.number_to_currency(v)
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
      return if key_data[:hide_from_overflow]

      i = nil if key_data[:skip_index]
      v = format_currency(v) if key_data[:dollar]
      v = v.extras_value if v.is_a?(PdfFill::FormValue)
      item_label = array_key_data.try(:[], :item_label)
      question_type = array_key_data&.dig(:question_type) || key_data&.dig(:question_type)
      array_format_options = array_key_data&.dig(:format_options) || {}
      key_format_options = key_data&.dig(:format_options) || {}
      format_options = array_format_options.merge(key_format_options)

      @extras_generator.add_text(
        v,
        key_data.slice(
          :question_num, :question_suffix, :question_text, :question_label, :checked_values, :show_suffix
        ).merge(
          i:, overflow:, item_label:, question_type:, format_options:
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

    def key_from_iterator_else_key(key_from_iterator, key, i)
      if key_from_iterator&.lambda?
        key_from_iterator.call(i)
      else
        key
      end
    end

    def set_value(v, key_data, i, from_array_overflow = false)
      k = key_from_iterator_else_key(key_data[:key_from_iterator], key_data[:key], i)
      new_value = convert_value(v, key_data)

      if k.present? && overflow?(key_data, new_value, from_array_overflow)
        add_to_extras(key_data, new_value, i)
        # NOTE: Allows for accommodating fields that don't have enough space for the full placeholder text
        # PDFtk doesn't care and truncates the text at the field limit, but HexaPDF will error out if the text
        # exceeds the field limit
        max_length = placeholder_text.length
        limit = @use_hexapdf ? key_data.fetch(:limit, max_length) : max_length
        new_value = placeholder_text[0...limit]
      elsif !from_array_overflow
        add_to_extras(key_data, new_value, i, overflow: false)
      end

      return if k.blank?

      # Allows the form to handle annoying, consecutively-numbered fields, for example RadioButtonList
      i = key_data[:iterator_offset].call(i) if key_data[:iterator_offset]&.lambda?

      # If multiple keys(read-only, etc) are mapped to the same value, set the value for each key
      # Example PDF field data:
      # {
      #   "key": "F[0].P3[0].VeteransName[0]",
      #   "question_text": "SECTION 1 - 1. A. VETERAN'S NAME (Last, First, Middle Name).",
      #   "options": null,
      #   "type": "Text"
      # },
      # {
      #   "key": "F[0].P4[0].VeteransName[0]",
      #   "question_text": "VETERAN'S NAME (Last, First, Middle Name). This is a read only field. It is " \
      #                    "pre-filled from Page 3.",
      #   "options": null,
      #   "type": "Text"
      # }
      # Example field mapping:
      # {
      #   key: ['F[0].P3[0].VeteransName[0]', 'F[0].P4[0].VeteransName[0]',
      #   question_text: "VETERAN'S NAME (Last, First, Middle Name)."
      # }
      k = k.gsub(ITERATOR, i.to_s) if !k.is_a?(Array) && i.present?

      if k.is_a?(Array)
        k.each do |key|
          @pdftk_form[key] = new_value
        end
      else
        @pdftk_form[k] = new_value
      end
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
          text = overflow?(pdftk_keys[k], v) ? placeholder_text : v

          set_value(text, pdftk_keys[k], idx, true) if pdftk_keys[k].is_a?(Hash)
        end
      end
    end

    def handle_overflow_and_label_first_key(pdftk_keys)
      first_key = pdftk_keys[:first_key]
      transform_data(
        form_data: { first_key => placeholder_text },
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
