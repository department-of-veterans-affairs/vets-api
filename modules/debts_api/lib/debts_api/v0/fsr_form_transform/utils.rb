# frozen_string_literal: true

module FsrFormTransform
  module Utils
    def dollars_cents(flt)
      flt.round(2).to_s.gsub(/^-?\d+\.\d{1}$/, '\00')
    end

    def re_camel(x)
      case x
      when Array
        x.map { |el| re_camel(el) }
      when Hash
        x.transform_keys { |key| key.camelcase(:lower) }.transform_values { |val| re_camel(val) }
      else
        x
      end
    end

    def re_dollar_cent(x, ignore = [])
      return re_dollar_cent_array(x, ignore) if x.instance_of?(Array)

      re_dollar_cent_hash(x, ignore) if x.instance_of?(Hash)
    end

    def re_dollar_cent_hash(x, ignore)
      result = {}
      x.each do |key, val|
        result[key] = if ignore.include?(key)
                        val.to_s
                      else
                        case val
                        when Integer
                          dollars_cents(val.to_f)
                        when Float
                          dollars_cents(val)
                        when Array
                          re_dollar_cent_array(val, ignore)
                        when Hash
                          re_dollar_cent_hash(val, ignore)
                        else
                          val
                        end
                      end
      end
      result
    end

    def re_dollar_cent_array(x, ignore)
      result = []
      x.each do |el|
        result << case el
                  when Integer
                    dollars_cents(el.to_f)
                  when Float
                    dollars_cents(el)
                  when Array
                    re_dollar_cent_array(el)
                  when Hash
                    re_dollar_cent_hash(el, ignore)
                  else
                    el
                  end
      end
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

    def exclude_expenses_by(expenses, names)
      expenses.filter { |expense| names.exclude?(expense['name']) }
    end

    def find_zipcode_data(zip)
      StdZipcode.find_by(zip_code: zip)
    end

    def str_to_num(str)
      return str if str.is_a? Numeric
      return 0 unless str.instance_of?(String)

      str.gsub(/[^0-9.-]/, '').to_i || 0
    end

    def sum_values(collection, key)
      collection&.sum { |item| item[key]&.gsub(/[^0-9.-]/, '')&.to_f } || 0
    end

    def format_number(number)
      format('%.2f', number).to_s
    end

    def safe_sum(array)
      array.map { |el| safe_number(el) }.sum.round(2)
    end

    def safe_number(str)
      return 0.0 if str.nil?

      str.gsub(/[^0-9.-]/, '').to_f
    end
  end
end
