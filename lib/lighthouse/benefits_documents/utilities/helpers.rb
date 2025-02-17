# frozen_string_literal: true

module BenefitsDocuments
  module Utilities
    module Helpers
      FILENAME_EXTENSION_MATCHER = /\.\w*$/
      OBFUSCATED_CHARACTER_MATCHER = /[a-zA-Z\d]/

      def self.generate_obscured_file_name(original_filename)
        extension = original_filename[FILENAME_EXTENSION_MATCHER]
        filename_without_extension = original_filename.gsub(FILENAME_EXTENSION_MATCHER, '')

        if filename_without_extension.length > 5
          # Obfuscate with the letter 'X'; we cannot obfuscate with special characters such as an asterisk,
          # as these filenames appear in VA Notify Mailers and their templating engine uses markdown.
          # Therefore, special characters can be interpreted as markdown and introduce formatting issues in the mailer
          obfuscated_portion = filename_without_extension[3..-3].gsub(OBFUSCATED_CHARACTER_MATCHER, 'X')
          filename_without_extension[0..2] + obfuscated_portion + filename_without_extension[-2..] + extension
        else
          original_filename
        end
      end

      def self.format_date_for_mailers(date)
        # We want to return all times in EDT
        timestamp = Time.at(date).in_time_zone('America/New_York')

        # We display dates in mailers in the format "May 1, 2024 3:01 p.m. EDT"
        timestamp.strftime('%B %-d, %Y %-l:%M %P %Z').sub(/([ap])m/, '\1.m.')
      end
    end
  end
end
