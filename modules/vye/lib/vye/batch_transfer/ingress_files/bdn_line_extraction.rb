# frozen_string_literal: true

module Vye
  module BatchTransfer
    module IngressFiles
      BdnLineExtraction = Struct.new(:line, :result, :award_lines, :awards) do
        def initialize(line:)
          super(line:, result: {}, award_lines: [], awards: [])

          extract_main
          extract_award_lines
          extract_indicator
          extract_awards
        end

        private

        def config
          @config ||= YAML.load_file Vye::Engine.root / 'config/bdn_line_extraction_config.yaml'
        end

        def extract_main
          config[:main_line]
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
            .product(config[:award_line].each_pair.to_a)
            .each do |(award_line, i), (field, length)|
              extracted = award_line.slice!(0...length).strip
              extracted = extracted.to_i / 100.0 if field == :monthly_rate

              awards[i] ||= {}
              awards[i].update(field => extracted)
            end
        end

        def extract_indicator
          return unless config[:indicator]

          result.update(indicator: line.slice!(0...1).strip)
        end

        public

        def attributes
          raise 'incomplete extraction' unless line.blank? && award_lines.all?(&:blank?)

          profile = result.slice(*config[:mappings][:profile])
          info = result.slice(*config[:mappings][:info])
          address = result.slice(*config[:mappings][:address]).merge(origin: 'backend')

          { profile:, info:, address:, awards: }
        end
      end
    end
  end
end
