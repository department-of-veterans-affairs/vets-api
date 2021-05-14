# frozen_string_literal: true

module VAForms
  class RegexHelper
    def scrub_query(search_term)
      search_term.strip
      search_term = check_prefix(search_term)
      # For 10-10 Forms
      ten_form_regex = /^10(?:[10 \s])?.*$/

      if search_term.match(ten_form_regex).present?
        search_term.sub!(/\s/, '-')
      elsif search_term.match(/21p/).present?
        search_term.sub!(/^21p/, '21P%')
        # Add a dash to DDD forms
      elsif search_term.match(/^\d\d\d/).present?
        search_term.sub!(/\d\d/, '\0%')
      end
      search_term
    end

    private

    def check_prefix(search_term)
      # The regex below checks to see if a form follows the DD(p)-DDDD format (with optional alpha characters)
      # Matches VA/GSA/SF prefixes with or without a space or dash
      va_prefix_regex = /^(?i)(.*)\bva\b(.*)/
      sf_form_regex = /^[sS][fF](?:[- \s \d])?\d+(?:[a-zA-Z])?(?:..)?$/
      gsa_form_regex = /^[gG][sS][aA](?:[- \s \d])?\d+(?:[a-zA-Z])?(?:..)?$/
      form_form_regex = /^(?i)(.*)\bform\b(.*)/
      if search_term.match(va_prefix_regex).present?
        # Scrub the 'VA' prefix, since not all forms have that, and keep just the number
        search_term.sub!(/(?:\s $)?[vV][aA]\s/, '')
      end
      if search_term.match(form_form_regex).present?
        # Scrub the 'form' prefix, since not all forms have that, and keep just the number
        search_term.sub!(/(?:\s $)?[fF][oO][rR][mM](?:\s $)?/, '')
      end
      if search_term.match(gsa_form_regex).present?
        # Scrub the 'GSA' prefix, since not all forms have that, and keep just the number
        search_term.gsub!(/\s/, '%').gsub!(/[gG][sS][aA]]/, '%')
      elsif search_term.match(sf_form_regex).present?
        # Scrub the 'SF' prefix, since not all forms have that, and keep just the number
        search_term.gsub!(/\s/, '%').gsub!(/[sF][fF]/, '%')
      end
      search_term
    end
  end
end
