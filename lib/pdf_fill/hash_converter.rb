# frozen_string_literal: true
module PdfFill
  class HashConverter
    ITERATOR = '%iterator%'

    def initialize(date_strftime)
      @pdftk_form = {}
      @date_strftime = date_strftime
    end

    def set_value(k, v)
      @pdftk_form[k] =
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
        pdftk_keys = pdftk_keys.gsub(ITERATOR, i.to_s) unless i.nil?
        set_value(pdftk_keys, form_data)
      end

      @pdftk_form
    end
  end
end
