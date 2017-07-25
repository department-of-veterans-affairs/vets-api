# frozen_string_literal: true
# module Preneeds
#   module Helpers
#     def xml_dates(params_with_dates)
#       params_with_dates.keys.each do |key|
#         value = params_with_dates[key]
#         params_with_dates[key] = if value.is_a? Hash
#                                    xml_dates(params_with_dates[key])
#                                  elsif value.is_a? Array
#                                    value.map { |v| complex?(v) ? xml_dates(v) : remove_hours(v) }
#                                  else
#                                    remove_hours(value)
#                                  end
#       end
#
#       params_with_dates
#     end
#
#     def json_symbolize(described)
#       JSON.parse(described.to_json, symbolize_names: true)
#     end
#
#     def complex?(v)
#       v.is_a?(Hash) || v.is_a?(Array)
#     end
#
#     def remove_hours(v)
#       v.to_s =~ /\d{4}-\d{2}-\d{2}T/ ? v.gsub(/T.*/, '') : v
#     end
#   end
# end
