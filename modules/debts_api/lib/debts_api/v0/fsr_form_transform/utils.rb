# frozen_string_literal: true

module FsrFormTransform
  module Utils
    def dollars_cents(flt)
      flt.round(2).to_s.gsub(/^\d+\.\d{1}$/, '\00')
    end

    def re_camel(x)
      return re_camel_array(x) if x.class == Array
      return re_camel_hash(x) if x.class == Hash
    end

    def re_camel_array(x)
      result = []
      x.each do |el|
        if el.class == Hash || el.class == Array
          result << re_camel(el)
        else
          result << el
        end
      end
      return result
    end

    def re_camel_hash(x)
      result = {}
      x.each do |key, val|
        if val.class == Hash || val.class == Array
          result[key.camelcase(:lower)] = re_camel(val)
        else
          result[key.camelcase(:lower)] = val
        end
      end
      return result
    end
  end
end
