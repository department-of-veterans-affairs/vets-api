# frozen_string_literal: true

require 'roo'
require 'octokit'

# rubocop:disable Rails/Output
module RepresentationManagement
  # Service to investigate registration number format discrepancies between the Excel file source
  # and AccreditedIndividual database records.
  #
  # This service analyzes registration numbers to identify patterns:
  # - Numeric format (1-5 digits): e.g., "123", "45678"
  # - UUID format: e.g., "550e8400-e29b-41d4-a716-446655440000"
  # - Other formats
  #
  # Usage in production console:
  #   investigator = RepresentationManagement::RegistrationNumberFormatInvestigator.new
  #   investigator.run
  #
  # This service is designed for console use and outputs progress via puts
  # to ensure visibility in the Rails console environment.
  class RegistrationNumberFormatInvestigator
    # UUID format regex
    UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    # Numeric format regex (1-5 digits)
    NUMERIC_REGEX = /\A\d{1,5}\z/

    def initialize
      @results = {}
      @data_comparison_service = DataComparisonService.new
    end

    # Runs the investigation and outputs results
    def run
      start_time = Time.zone.now
      print_header(start_time)

      begin
        file_individuals = download_and_extract_file_data
        return unless file_individuals

        db_individuals = query_database
        categorize_and_compare(file_individuals, db_individuals)
        print_detailed_results
        print_completion(start_time)
      rescue => e
        handle_error(e)
      end
    end

    private

    def print_header(start_time)
      puts "\n#{'=' * 80}"
      puts 'REGISTRATION NUMBER FORMAT INVESTIGATION'
      puts "Started at: #{start_time}"
      puts "#{'=' * 80}\n\n"
    end

    def download_and_extract_file_data
      puts "[#{Time.zone.now}] Step 1/3: Downloading and extracting Excel file..."
      file_content = @data_comparison_service.send(:download_file)
      return nil unless file_content

      individuals = extract_individuals_from_file(file_content)
      puts "[#{Time.zone.now}]   ✓ Found #{individuals.size} unique individuals in file\n\n"
      individuals
    end

    def query_database
      puts "[#{Time.zone.now}] Step 2/3: Querying AccreditedIndividual database..."
      db_individuals = Set.new(AccreditedIndividual.pluck(:registration_number).map(&:to_s))
      puts "[#{Time.zone.now}]   ✓ Found #{db_individuals.size} records in database\n\n"
      db_individuals
    end

    def categorize_and_compare(file_individuals, db_individuals)
      puts "[#{Time.zone.now}] Step 3/3: Categorizing and comparing..."

      # Determine which registration numbers are in which groups
      in_both = file_individuals & db_individuals
      in_db_not_file = db_individuals - file_individuals

      puts "[#{Time.zone.now}]   Analyzing 'In Both' group (#{in_both.size} records)..."
      @results[:in_both] = categorize_registration_numbers(in_both)

      puts "[#{Time.zone.now}]   Analyzing 'In DB but NOT in File' group (#{in_db_not_file.size} records)..."
      @results[:in_db_not_file] = categorize_registration_numbers(in_db_not_file)

      puts "[#{Time.zone.now}]   ✓ Categorization complete\n\n"
    end

    def categorize_registration_numbers(registration_numbers)
      categories = {
        numeric: [],
        uuid: [],
        other: [],
        uuid_by_type: {
          attorney: [],
          claims_agent: [],
          representative: []
        }
      }

      registration_numbers.each do |reg_num|
        if reg_num.match?(NUMERIC_REGEX)
          categories[:numeric] << reg_num
        elsif reg_num.match?(UUID_REGEX)
          categories[:uuid] << reg_num
        else
          categories[:other] << reg_num
        end
      end

      # Fetch individual_type for all UUID records in one query
      if categories[:uuid].any?
        uuid_records = AccreditedIndividual.where(registration_number: categories[:uuid])
                                           .pluck(:registration_number, :individual_type)
        uuid_records.each do |reg_num, type|
          categories[:uuid_by_type][type.to_sym] << reg_num if type
        end
      end

      categories
    end

    def print_detailed_results
      puts "\n#{'=' * 80}"
      puts 'DETAILED FORMAT ANALYSIS'
      puts "#{'=' * 80}\n\n"

      print_category_analysis('Records in BOTH File and Database', @results[:in_both])
      puts "\n#{'-' * 80}\n\n"

      print_category_analysis('Records in Database but NOT in File', @results[:in_db_not_file])

      # Compare individual_type distribution between the two groups
      if @results[:in_both][:uuid].any? && @results[:in_db_not_file][:uuid].any?
        puts "\n#{'-' * 80}\n\n"
        puts 'INDIVIDUAL TYPE COMPARISON FOR UUID RECORDS:\n\n'
        compare_uuid_type_distribution
      end
    end

    def print_category_analysis(title, categories)
      total = categories[:numeric].size + categories[:uuid].size + categories[:other].size

      puts "#{title}:"
      puts "  Total: #{total}"
      puts "  - Numeric (1-5 digits): #{categories[:numeric].size} (#{percentage(categories[:numeric].size, total)}%)"
      puts "  - UUID format: #{categories[:uuid].size} (#{percentage(categories[:uuid].size, total)}%)"
      puts "  - Other format: #{categories[:other].size} (#{percentage(categories[:other].size, total)}%)"

      print_samples('Numeric', categories[:numeric], 20)
      print_samples('UUID', categories[:uuid], 10)
      print_samples('Other', categories[:other], 10)

      # Print individual_type breakdown for UUID records
      print_uuid_type_breakdown(categories[:uuid_by_type]) if categories[:uuid].any?

      # Get detailed info for UUID samples if any exist
      if categories[:uuid].any?
        puts "\n  Detailed info for UUID registration numbers (first 5):"
        fetch_detailed_records(categories[:uuid].first(5))
      end
    end

    def print_samples(category_name, items, limit)
      return if items.empty?

      puts "\n  Sample #{category_name} registration numbers (showing first #{limit}):"
      items.sort.first(limit).each { |num| puts "    #{num}" }
      puts "    ... (#{items.size - limit} more)" if items.size > limit
    end

    def print_uuid_type_breakdown(uuid_by_type)
      total_uuid = uuid_by_type.values.sum(&:size)
      return if total_uuid.zero?

      puts "\n  UUID records by individual_type:"
      puts "    - Attorney: #{uuid_by_type[:attorney].size} (#{percentage(uuid_by_type[:attorney].size, total_uuid)}%)"
      puts "    - Claims Agent: #{uuid_by_type[:claims_agent].size} (#{percentage(uuid_by_type[:claims_agent].size,
                                                                                  total_uuid)}%)"
      puts "    - Representative: #{uuid_by_type[:representative].size} (#{percentage(
        uuid_by_type[:representative].size, total_uuid
      )}%)"
    end

    def fetch_detailed_records(registration_numbers)
      records = AccreditedIndividual.where(registration_number: registration_numbers)
      records.each do |record|
        puts "    Registration: #{record.registration_number}"
        puts "      ID: #{record.id}"
        puts "      OGC ID: #{record.ogc_id}"
        puts "      Type: #{record.individual_type}"
        puts "      Name: #{record.full_name}"
        puts "      POA Code: #{record.poa_code.presence || 'N/A'}"
        puts "      Created: #{record.created_at}"
        puts "      Updated: #{record.updated_at}"
        puts ''
      end
    end

    def percentage(count, total)
      return 0.0 if total.zero?

      ((count.to_f / total) * 100).round(2)
    end

    def compare_uuid_type_distribution
      both_types = @results[:in_both][:uuid_by_type]
      db_only_types = @results[:in_db_not_file][:uuid_by_type]

      puts '  In BOTH file and DB:'
      puts "    - Attorney: #{both_types[:attorney].size}"
      puts "    - Claims Agent: #{both_types[:claims_agent].size}"
      puts "    - Representative: #{both_types[:representative].size}"

      puts '\n  In DB but NOT in file:'
      puts "    - Attorney: #{db_only_types[:attorney].size}"
      puts "    - Claims Agent: #{db_only_types[:claims_agent].size}"
      puts "    - Representative: #{db_only_types[:representative].size}"
    end

    def print_completion(start_time)
      elapsed = Time.zone.now - start_time
      puts "\n[#{Time.zone.now}] Investigation completed in #{elapsed.round(2)} seconds"
      puts "#{'=' * 80}\n"
    end

    def handle_error(error)
      puts "\n[#{Time.zone.now}] ERROR: #{error.class}: #{error.message}"
      puts error.backtrace.first(10).join("\n")
      puts "\nInvestigation failed. Please check the error above."
    end

    # Extracts all unique registration numbers from the Excel file
    # Uses DataComparisonService's private methods for extraction logic
    # @param file_content [String] The raw file content
    # @return [Set] Set of individual registration numbers
    def extract_individuals_from_file(file_content)
      puts "[#{Time.zone.now}]   Opening Excel file..."
      xlsx = Roo::Spreadsheet.open(StringIO.new(file_content), extension: :xlsx)

      individuals = Set.new
      @data_comparison_service.send(:extract_individuals_from_sheets, xlsx, individuals)

      individuals
    end
  end
end
# rubocop:enable Rails/Output
