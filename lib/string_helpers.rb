# frozen_string_literal: true

require 'levenshtein'

module StringHelpers
  module_function

  def capitalize_only(str)
    str.slice(0, 1).capitalize + str.slice(1..-1)
  end

  def mask_sensitive(string)
    string&.gsub(/.(?=.{4})/, '*')
  end

  def hyphenated_ssn(ssn)
    return if ssn.blank?

    "#{ssn[0..2]}-#{ssn[3..4]}-#{ssn[5..8]}"
  end

  def levenshtein_distance(str_a, str_b)
    Levenshtein.distance(str_a, str_b)
  end

  def heuristics(str_a, str_b)
    {
      length: [str_a.length, str_b.length],
      only_digits: [str_a.scan(/^\d+$/).any?, str_b.scan(/^\d+$/).any?],
      encoding: [str_a.encoding.to_s, str_b.encoding.to_s],
      levenshtein_distance: levenshtein_distance(str_a, str_b)
    }
  end
end
