# frozen_string_literal: true

module VAForms
  class RegexHelper
    def scrub_query(search_term)
      search_term = check_prefix(search_term)
      # Matches 10-10 Forms
      ten_form_regex = /^10\s*10(\s?.*)$/
      # Looks for the common 10 10 and make it 10-10
      if search_term.match(ten_form_regex).present?
        search_term = "10-10#{Regexp.last_match(1)}"
        return search_term
      end
      search_term
    end

    def strip_va(number)
      number.gsub(/VA/, '')
    end

    private

    def check_prefix(search_term)
      # Matches VA/GSA prefixes with or without a space or dash
      va_prefix_regex = /^(?i)(.*)\bva\b(.*)/
      form_form_regex = /^(?i)(.*)\bform\b(.*)/
      if search_term.match(va_prefix_regex).present?
        # Scrub the 'VA' prefix, since not all forms have that, and keep just the number
        search_term = "#{Regexp.last_match(1)}#{Regexp.last_match(2)}"
        search_term = search_term.strip
        search_term = search_term.gsub(/-/, '%')
      end
      if search_term.match(form_form_regex).present?
        # Scrub the 'form' term, since not all forms have that, and keep just the number
        search_term = "#{Regexp.last_match(1)}#{Regexp.last_match(2)}"
        search_term = search_term.strip
        search_term = search_term.gsub(/-/, '%')
      end
      search_term
    end
  end
end
