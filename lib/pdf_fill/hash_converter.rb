module PdfFill
  class HashConverter
    def initialize(pdftk_keys, form_data)
      @pdftk_keys = pdftk_keys
      @form_data = form_data
      @pdftk_form = {}
    end

    def transform_data(
      form_data: @form_data,
      pdftk_keys: @pdftk_keys,
      i: nil
    )
      case form_data
      when Array
        form_data.each_with_index do |v, i|
          transform_data(form_data: v, pdftk_keys: pdftk_keys, i: i + 1)
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

        @pdftk_form[pdftk_keys] = if [true, false].include?(form_data)
          form_data ? 1 : 0
        else
          form_data.to_s
        end
      end

      @pdftk_form
    end
  end
end
