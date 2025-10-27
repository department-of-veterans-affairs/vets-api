# frozen_string_literal: true

module VcrInspector
  class CassetteFinder
    def self.all_cassettes(root_path)
      Dir.glob(File.join(root_path, '**/*.yml')).map do |file_path|
        relative_path = file_path.sub("#{root_path}/", '').sub('.yml', '')
        {
          path: relative_path,
          name: File.basename(file_path, '.yml'),
          service: relative_path.split('/').first,
          full_path: file_path,
          modified_at: File.mtime(file_path)
        }
      end.sort_by { |c| c[:path] }
    end

    def self.search(root_path, query, filters = {})
      cassettes = all_cassettes(root_path)
      
      # Text search
      if query && !query.empty?
        cassettes = cassettes.select do |c|
          c[:path].downcase.include?(query.downcase) ||
            c[:name].downcase.include?(query.downcase)
        end
      end

      # Service filter
      if filters[:service] && !filters[:service].empty?
        cassettes = cassettes.select { |c| c[:service] == filters[:service] }
      end

      # For method and status filters, we need to parse the cassette
      if filters[:method] || filters[:status]
        cassettes = cassettes.select do |c|
          parsed = CassetteParser.parse(c[:full_path])
          next false unless parsed[:interactions]&.any?

          interaction = parsed[:interactions].first
          method_match = !filters[:method] || 
                        interaction[:request][:method].to_s.upcase == filters[:method].upcase
          status_match = !filters[:status] || 
                        interaction[:response][:status][:code].to_s == filters[:status]
          
          method_match && status_match
        end
      end

      cassettes
    end

    def self.group_by_service(cassettes)
      cassettes.group_by { |c| c[:service] }
               .transform_values(&:count)
               .sort_by { |_k, v| -v }
               .to_h
    end
  end
end
