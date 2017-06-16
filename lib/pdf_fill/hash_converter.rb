require 'pdf_fill/extras_generator'

# frozen_string_literal: true
module PdfFill
  class HashConverter
    ITERATOR = '%iterator%'

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
        v = v.to_s

        date_split = v.split('-')
        date_args = Array.new(3) { |i| date_split[i].to_i }

        if Date.valid_date?(*date_args)
          Date.new(*date_args).strftime(@date_strftime)
        else
          v
        end
      end
    end

    def set_value(k, v, key_data)
      new_value = convert_value(v)

      if key_data[:limit].present? && new_value.size > key_data[:limit]
        @extras_generator.add_text("#{key_data[:question]}. #{new_value}")
        new_value = "See add'l info page"
      end

      @pdftk_form[k] = new_value
    end

    def transform_data(form_data:, pdftk_keys:, i: nil)
      return if form_data.nil? || pdftk_keys.nil?

      case form_data
      when Array
        form_data.each_with_index do |v, idx|
          transform_data(form_data: v, pdftk_keys: pdftk_keys, i: idx)
        end
      when Hash
        form_data.each do |k, v|
          transform_data(
            form_data: v,
            pdftk_keys: pdftk_keys[k],
            i: i
          )
        end
      else
        key = pdftk_keys[:key]
        key = key.gsub(ITERATOR, i.to_s) unless i.nil?
        set_value(key, form_data, pdftk_keys)
      end

      @pdftk_form
    end
  end
end
