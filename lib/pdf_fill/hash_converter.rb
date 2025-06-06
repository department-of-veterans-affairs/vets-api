# frozen_string_literal: true

require 'pdf_fill/form_value'

module PdfFill
  class HashConverter
    ITERATOR = '%iterator%'

    attr_reader :extras_generator, :placeholder_links

    delegate :placeholder_text, to: :extras_generator

    def initialize(date_strftime, extras_generator)
      @pdftk_form = {}
      @date_strftime = date_strftime
      @extras_generator = extras_generator
      @placeholder_links = [] # Track fields that got placeholder text
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
      return if key_data[:hide_from_overflow]

      i = nil if key_data[:skip_index]
      v = "$#{v}" if key_data[:dollar]
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

    def set_value(v, key_data, i, from_array_overflow = false)
      k = key_data[:key]

      return if k.blank?
    

      k = k.gsub(ITERATOR, i.to_s) unless i.nil?

      new_value = convert_value(v, key_data)

      if overflow?(key_data, new_value, from_array_overflow)

        add_to_extras(key_data, new_value, i)

        # Track this field for linking
        track_placeholder_link(k, key_data)
        new_value = placeholder_text
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
            key_data = pdftk_keys[k]
            next unless key_data.is_a?(Hash)

            if overflow?(key_data, v)
              text = placeholder_text
              track_placeholder_link(nil, key_data, idx)
            else
              text = v
            end

            set_value(text, key_data, idx, true)
          end
        end
    end

    def handle_overflow_and_label_first_key(pdftk_keys)
      first_key = pdftk_keys[:first_key]

      # Track this as a placeholder link since we're setting placeholder text
      if pdftk_keys[:question_num] && pdftk_keys[first_key]
        first_key_data = pdftk_keys[first_key]
        # Create a field key for the first field that will get placeholder text
        field_key = first_key_data[:key]&.gsub(ITERATOR, '0') || "array_overflow_#{pdftk_keys[:question_num]}"
        track_placeholder_link(field_key, first_key_data)
      end

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

    private

    def track_placeholder_link(field_key, key_data, idx = nil)
      question_num = key_data[:question_num]
      return unless question_num

      if idx
        modified_key_data = key_data.dup
        if key_data[:page] && key_data[:x] && key_data[:y]
          # Support coordinate arrays (if implemented) or fall back to mathematical offset
          if key_data[:x].is_a?(Array) && key_data[:y].is_a?(Array)
            # Use array coordinates if available
            modified_key_data[:x] = key_data[:x][idx] || key_data[:x].first
            modified_key_data[:y] = key_data[:y][idx] || key_data[:y].first
            modified_key_data[:page] = key_data[:page][idx] || key_data[:page].first
          else
            # Fall back to current mathematical offset approach
            modified_key_data[:x] = key_data[:x]
            modified_key_data[:y] = key_data[:y] - (idx * 50)
          end
        end
        
        key_data = modified_key_data
      end

      # Store the field info for later link creation
      @placeholder_links << {
        question_num:,
        dest_name: key_data[:overflow_destination],
        label: key_data[:question_text],
        page: key_data[:page],
        x: key_data[:x],
        y: key_data[:y],
        width: key_data[:width]
      }
    end
  end
end
