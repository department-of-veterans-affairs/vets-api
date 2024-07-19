# frozen_string_literal: true

module Vye
  module BatchTransfer
    module IngressFiles
      BDN_LINE_EXTRACTION_ATTRIBUTES =
        %i[original_line line result original_award_lines award_lines awards].freeze

      BdnLineExtraction = Struct.new(*BDN_LINE_EXTRACTION_ATTRIBUTES) do
        def initialize(line:)
          original_line = line.dup
          super(original_line:, line:, result: {}, original_award_lines:, award_lines: [], awards: [])

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
          self.original_award_lines = award_lines.map(&:dup)
        end

        def extract_awards
          # iterate over the fields for each award line and extract the data
          # think list comprehensions in python, haskell, or erlang
          award_lines
            .each_with_index.to_a
            .product(config[:award_line].each_pair.to_a)
            .each do |(award_line, i), (field, length)|
              extracted = award_line.slice!(0...length).strip
              awards[i] ||= {}
              awards[i].update(field => extracted)
            end
        end

        def extract_indicator
          return unless config[:indicator]

          result.update(indicator: line.slice!(0...1).strip)
        end

        public

        def records
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
