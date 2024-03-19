# frozen_string_literal: true

module Vye
  module BatchTransfer
    module IngressFiles
      BdnLineExtraction = Struct.new(:line, :result, :award_lines, :awards) do
        def initialize(line:, result:, award_lines:, awards:)
          super

          extract_main
          extract_award_lines
          extract_indicator
          extract_awards
        end

        def extract_main
          BDN_FEED_CONFIG[:main_line]
            .each do |field, length|
              extracted = line.slice!(0...length).strip
              result.update(field => extracted)
            end
        end

        def extract_award_lines
          (0...4)
            .each do |_i|
              dead = line[0...8].strip == ''
              extracted = line.slice!(0...41)
              award_lines << extracted unless dead
            end
        end

        def extract_awards
          # iterate over the fields for each award line and extract the data
          # think list comprehensions in python, haskell, or erlang
          award_lines
            .each_with_index.to_a
            .product(BDN_FEED_CONFIG[:award_line].each_pair.to_a)
            .each do |(award_line, i), (field, length)|
              extracted = award_line.slice!(0...length).strip
              awards[i] ||= {}
              awards[i].update(field => extracted)
            end
        end

        def extract_indicator
          result.update(indicator: line.slice!(0...1).strip)
        end

        def attributes
          raise 'incomplete extraction' unless line.blank? && award_lines.all?(&:blank?)

          profile =
            result
            .slice(*%i[
                     ssn file_number
                   ])
          info =
            result
            .slice(*%i[
                     ssn file_number
                     dob mr_status rem_ent cert_issue_date del_date date_last_certified
                     stub_nm rpo_code fac_code payment_amt indicator
                   ])
          address =
            result
            .slice(*%i[
                     veteran_name address1 address2 address3 address4 address5 zip_code
                   ])

          { profile:, info:, address:, awards: }
        end
      end
    end
  end
end
