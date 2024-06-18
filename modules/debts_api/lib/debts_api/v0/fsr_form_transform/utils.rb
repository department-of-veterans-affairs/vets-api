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

    def re_dollar_cent(x)
      return re_dollar_cent_array(x) if x.instance_of?(Array)
      re_dollar_cent_hash(x) if x.instance_of?(Hash)
    end

    def re_dollar_cent_hash(x)
      result = {}
      x.each do |key, val|
        case val
        when Integer
          result[key] = dollars_cents(val.to_f)
        when Float
          result[key] = dollars_cents(val)
        when Array
          result[key] = re_dollar_cent_array(val)
        when Hash
          result[key] = re_dollar_cent_hash(val)
        else
          result[key] = val
        end
      end
      result
    end

    def re_dollar_cent_array(x)
      result = []
      x.each{ |el|
        case el
        when Integer
          result << dollars_cents(el.to_f)
        when Float
          result << dollars_cents(el)
        when Array
          result << re_dollar_cent_array(el)
        when Hash
          result << re_dollar_cent_hash(el)
        else
          result << el
        end
      }
      result
    end

    def sanitize_date_string(date)
      return '' if date.empty?

      date_string = date.gsub('XX', '01')
      date_string << '-01' if date_string.split('-').length == 2
      year, month = date_string.split('-')
      month = "0#{month}" if month.length == 1
      "#{month}/#{year}"
    end

    def str_to_num(str)
      return str if str.is_a? Numeric
      return 0 unless str.instance_of?(String)

      str.gsub(/[^0-9.-]/, '').to_i || 0
    end

    def format_number(number)
      format('%.2f', number).to_s
    end
  end
end
