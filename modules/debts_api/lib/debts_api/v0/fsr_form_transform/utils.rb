# frozen_string_literal: true

module FsrFormTransform
  module Utils
    def dollars_cents(flt)
      flt.round(2).to_s.gsub(/^\d+\.\d{1}$/, '\00')
    end

    def re_camel(x)
      return re_camel_array(x) if x.instance_of?(Array)

      re_camel_hash(x) if x.instance_of?(Hash)
    end

    def re_camel_array(x)
      result = []
      x.each do |el|
        result << if el.instance_of?(Hash) || el.instance_of?(Array)
                    re_camel(el)
                  else
                    el
                  end
      end
      result
    end

    def re_camel_hash(x)
      result = {}
      x.each do |key, val|
        result[key.camelcase(:lower)] = if val.instance_of?(Hash) || val.instance_of?(Array)
                                          re_camel(val)
                                        else
                                          val
                                        end
      end
      result
    end
  end
end
