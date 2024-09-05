# frozen_string_literal: true

module VAOS
  module Strings
    # This method filters out non-printable characters from a given string returning
    # only 7 bit printable ascii, newline, tab and carriage return characters.
    #
    # @param str [String] The string to be filtered.
    # @return [String] The filtered string containing only ASCII characters.
    # If the input is not a string, the method will return the input as is.
    #
    def self.filter_ascii_characters(str)
      return str unless str.is_a?(String)

      str.each_char.grep(/[\x20-\x7E\r\n\t]/).join
    end
  end
end
