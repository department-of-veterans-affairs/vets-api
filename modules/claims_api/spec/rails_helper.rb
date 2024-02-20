# frozen_string_literal: true

require 'spec_helper'
require 'support/factory_bot'
require_relative 'support/auth_helper'
require_relative 'support/stub_claims_api_auth_token'
require 'bd/bd'
require 'evss_service/base'

RSpec.configure do |config|
  config.after(:suite) do
    # # words = %w[ssn secret password security private key id login ssn Full Mailing address Phone Email Social security Drivers license Passport Alien registration Financial Biometric DNA Citizenship documentation Medical Ethnic affiliation identification Sexual orientation Account password birth Criminal history Mothers maiden Credit card].each(&:downcase) # rubocop:disable Layout/LineLength
    # exclusions = %w[model_id failure arguments filtered error 'data key']
    # File.readlines('log/development.log', chomp: true).each_with_index do |line, index|
    #   File.readlines('modules/claims_api/spec/support/pii_key_words.txt', chomp: true).each do |phrase|
    #     # line_segments = line.split.each(&:downcase!)
    #     # intersection = line_segments & words
    #     # if intersection.present?
    #     include_line = []
    #     line.split.each do |segment|
    #       if segment.to_s.downcase.scan(/#{phrase.downcase}/).present?
    #         exclusions.each do |e|
    #           include_line << index if segment.to_s.downcase.scan(/#{e}/).blank?
    #         end
    #       end
    #       results << { line: "line number: #{index}, word/s: #{phrase}, line: #{line}" } if include_line.present?
    #     end
    #     # end
    #   end
    # end
    results = `fgrep -f modules/claims_api/spec/support/pii_key_words.txt log/development.log`
    if results.present?
      puts ''
      puts '======================================='
      puts 'Start check for PII in development log'
      puts '======================================='
      puts results
      puts '======================================='
      puts 'End check for PII in development log'
      puts '======================================='
    end
  end
end
