# frozen_string_literal: true

module VcrInspector
  class CassetteFinder
    def self.all_cassettes(root_path)
      cassettes = Dir.glob(File.join(root_path, '**/*.yml')).map do |file_path|
        build_cassette_info(root_path, file_path)
      end

      cassettes.sort_by { |c| c[:path] }
    end

    def self.build_cassette_info(root_path, file_path)
      relative_path = file_path.sub("#{root_path}/", '').sub('.yml', '')
      recorded_at = parse_recorded_at(file_path)

      {
        path: relative_path,
        name: File.basename(file_path, '.yml'),
        service: relative_path.split('/').first,
        full_path: file_path,
        modified_at: File.mtime(file_path),
        recorded_at: recorded_at || File.mtime(file_path)
      }
    end

    # rubocop:disable Rails/TimeZone - standalone script without ActiveSupport
    def self.parse_recorded_at(file_path)
      yaml = YAML.load_file(file_path)
      recorded_at = extract_interaction_dates(yaml)
      recorded_at ||= Time.parse(yaml['recorded_at']) if yaml['recorded_at']
      recorded_at
    rescue
      nil
    end

    def self.extract_interaction_dates(yaml)
      return nil unless yaml['http_interactions']&.any?

      dates = yaml['http_interactions'].map { |i| i['recorded_at'] }.compact
      Time.parse(dates.max) if dates.any?
    rescue
      nil
    end
    # rubocop:enable Rails/TimeZone

    # rubocop:disable Rails/Present - standalone script without ActiveSupport
    def self.search(root_path, query, filters = {})
      cassettes = all_cassettes(root_path)
      cassettes = apply_text_search(cassettes, query)
      cassettes = apply_service_filter(cassettes, filters[:service])
      apply_method_status_filters(cassettes, filters)
    end

    def self.apply_text_search(cassettes, query)
      return cassettes unless query && !query.empty?

      cassettes.select do |c|
        c[:path].downcase.include?(query.downcase) ||
          c[:name].downcase.include?(query.downcase)
      end
    end

    def self.apply_service_filter(cassettes, service)
      return cassettes unless service && !service.empty?

      cassettes.select { |c| c[:service] == service }
    end
    # rubocop:enable Rails/Present

    def self.apply_method_status_filters(cassettes, filters)
      return cassettes unless filters[:method] || filters[:status]

      cassettes.select do |c|
        matches_method_and_status?(c, filters)
      end
    end

    def self.matches_method_and_status?(cassette, filters)
      parsed = CassetteParser.parse(cassette[:full_path])
      return false unless parsed[:interactions]&.any?

      interaction = parsed[:interactions].first
      method_match = !filters[:method] ||
                     interaction[:request][:method].to_s.upcase == filters[:method].upcase
      status_match = !filters[:status] ||
                     interaction[:response][:status][:code].to_s == filters[:status]

      method_match && status_match
    end

    def self.group_by_service(cassettes)
      cassettes.group_by { |c| c[:service] }
               .transform_values(&:count)
               .sort_by { |_k, v| -v }
               .to_h
    end
  end
end
