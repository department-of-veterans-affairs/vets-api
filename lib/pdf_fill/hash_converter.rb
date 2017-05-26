# frozen_string_literal: true
module PdfFill
  class HashConverter
    ITERATOR = '%iterator%'

    def initialize
      @pdftk_form = {}
    end

    def set_value(k, v)
      @pdftk_form[k] =
        if [true, false].include?(v)
          v ? 1 : 0
        else
          v.to_s
        end
    end

    def transform_data(form_data:, pdftk_keys:, i: nil)
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
