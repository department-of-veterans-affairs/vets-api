# frozen_string_literal: true

require 'roo'
require 'octokit'

# rubocop:disable Rails/Output
module RepresentationManagement
  # Service to compare representative and organization data from the Excel file source
  # against database models.
  #
  # This service downloads the Excel file and compares identifiers to report discrepancies
  # between the file data and four database models:
  # - Veteran::Service::Representative (file vs DB)
  # - AccreditedIndividual (file vs DB)
  # - Veteran::Service::Organization (file vs DB)
  # - AccreditedOrganization (file vs DB)
  #
  # Usage in production console:
  #   service = RepresentationManagement::DataComparisonService.new
  #   service.run
  #
  # This service is designed for console use and outputs progress via puts
  # to ensure visibility in the Rails console environment.
  class DataComparisonService
    # Constants for GitHub file location
    GITHUB_ORG = 'department-of-veterans-affairs'
    GITHUB_REPO = 'va.gov-team-sensitive'
    GITHUB_PATH = 'products/accredited-representation-management/data/rep-org-addresses.xlsx'

    def initialize
      @results = {}
    end

    # Runs the comparison and outputs results
    def run
      start_time = Time.zone.now
      print_header(start_time)

      begin
        file_content = fetch_and_validate_file
        return unless file_content

        file_data = extract_and_report_file_data(file_content)
        db_data = query_and_report_database_data
        compare_and_report(file_data, db_data)
        print_completion(start_time)
      rescue => e
        handle_error(e)
      end
    end

    private

    def print_header(start_time)
      puts "\n#{'=' * 80}"
      puts 'REPRESENTATION DATA COMPARISON'
      puts "Started at: #{start_time}"
      puts "#{'=' * 80}\n\n"
    end

    def fetch_and_validate_file
      puts "[#{Time.zone.now}] Step 1/4: Downloading Excel file from GitHub..."
      file_content = download_file
      puts "[#{Time.zone.now}]   ✓ File downloaded successfully\n\n" if file_content
      file_content
    end

    def extract_and_report_file_data(file_content)
      puts "[#{Time.zone.now}] Step 2/4: Extracting identifiers from Excel file..."
      file_data = extract_identifiers_from_file(file_content)
      puts "[#{Time.zone.now}]   ✓ Found #{file_data[:individuals].size} unique individuals"
      puts "[#{Time.zone.now}]   ✓ Found #{file_data[:organizations].size} unique organizations\n\n"
      file_data
    end

    def query_and_report_database_data
      puts "[#{Time.zone.now}] Step 3/4: Querying database models..."
      db_data = query_database_models
      print_database_counts(db_data)
      db_data
    end

    def print_database_counts(db_data)
      puts "[#{Time.zone.now}]   ✓ Veteran::Service::Representative: #{db_data[:veteran_reps].size} records"
      puts "[#{Time.zone.now}]   ✓ AccreditedIndividual: #{db_data[:accredited_individuals].size} records"
      puts "[#{Time.zone.now}]   ✓ Veteran::Service::Organization: #{db_data[:veteran_orgs].size} records"
      puts "[#{Time.zone.now}]   ✓ AccreditedOrganization: #{db_data[:accredited_orgs].size} records\n\n"
    end

    def compare_and_report(file_data, db_data)
      puts "[#{Time.zone.now}] Step 4/4: Performing comparisons..."
      perform_comparisons(file_data, db_data)
      puts ''
      print_results
    end

    def print_completion(start_time)
      elapsed = Time.zone.now - start_time
      puts "\n[#{Time.zone.now}] Completed in #{elapsed.round(2)} seconds"
      puts "#{'=' * 80}\n"
    end

    def handle_error(error)
      puts "\n[#{Time.zone.now}] ERROR: #{error.class}: #{error.message}"
      puts error.backtrace.first(10).join("\n")
      puts "\nComparison failed. Please check the error above."
    end

    # Downloads the Excel file from GitHub
    # @return [String, nil] File content or nil if download failed
    def download_file
      setup_github_client
      file_info = fetch_github_file_info
      fetch_file_content(file_info.download_url)
    rescue => e
      puts "[#{Time.zone.now}]   ERROR: Failed to download file from GitHub"
      puts "[#{Time.zone.now}]   Error: #{e.message}"
      puts "[#{Time.zone.now}]   Check GitHub access token and network connectivity"
      nil
    end

    # Sets up the Octokit GitHub client with an access token
    def setup_github_client
      @github_client = Octokit::Client.new(access_token: Settings.xlsx_file_fetcher.github_access_token)
    end

    # Retrieves the file information for the XLSX file from GitHub
    # @return [Sawyer::Resource] The file information resource from GitHub
    def fetch_github_file_info
      @github_client.contents("#{GITHUB_ORG}/#{GITHUB_REPO}", path: GITHUB_PATH)
    end

    # Downloads the file content from a given URL
    # @param url [String] The URL to download the file content from
    # @return [String] The body of the HTTP response, or nil if not successful
    def fetch_file_content(url)
      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      response.body if response.is_a?(Net::HTTPSuccess)
    end

    # Extracts all unique registration numbers and POA codes from the Excel file
    # @param file_content [String] The raw file content
    # @return [Hash] Hash with :individuals and :organizations Sets
    def extract_identifiers_from_file(file_content)
      puts "[#{Time.zone.now}]   Opening Excel file..."
      xlsx = Roo::Spreadsheet.open(StringIO.new(file_content), extension: :xlsx)

      individuals = Set.new
      organizations = Set.new
      extract_individuals_from_sheets(xlsx, individuals)
      extract_organizations_from_vso_sheet(xlsx, organizations)

      { individuals:, organizations: }
    end

    def extract_individuals_from_sheets(xlsx, individuals)
      total_rows = 0
      %w[Attorneys Agents Representatives].each do |sheet_name|
        next unless xlsx.sheets.include?(sheet_name)

        total_rows = process_individual_sheet(xlsx, sheet_name, individuals, total_rows)
      end
      total_rows
    end

    def process_individual_sheet(xlsx, sheet_name, individuals, total_rows)
      puts "[#{Time.zone.now}]   Processing #{sheet_name} sheet..."
      sheet = xlsx.sheet(sheet_name)
      number_col = sheet.row(1).index('Number')

      unless number_col
        puts "[#{Time.zone.now}]     WARNING: 'Number' column not found in #{sheet_name}"
        return total_rows
      end

      total_rows = collect_individual_numbers(sheet, number_col, individuals, total_rows)
      puts "[#{Time.zone.now}]     #{sheet_name}: #{sheet.last_row - 1} rows"
      total_rows
    end

    def collect_individual_numbers(sheet, number_col, individuals, total_rows)
      (2..sheet.last_row).each do |row_num|
        number = sheet.row(row_num)[number_col]
        individuals.add(number.to_s) if number
        total_rows += 1
        puts "[#{Time.zone.now}]     Processed #{total_rows} rows across all sheets..." if (total_rows % 2500).zero?
      end
      total_rows
    end

    def extract_organizations_from_vso_sheet(xlsx, organizations)
      unless xlsx.sheets.include?('VSOs')
        puts "[#{Time.zone.now}]   WARNING: VSOs sheet not found"
        return
      end

      puts "[#{Time.zone.now}]   Processing VSOs sheet..."
      sheet = xlsx.sheet('VSOs')
      poa_col = sheet.row(1).index('POA')

      unless poa_col
        puts "[#{Time.zone.now}]     WARNING: 'POA' column not found in VSOs sheet"
        return
      end

      (2..sheet.last_row).each do |row_num|
        poa = sheet.row(row_num)[poa_col]
        organizations.add(poa.to_s.strip.upcase) if poa
      end
      puts "[#{Time.zone.now}]     VSOs: #{sheet.last_row - 1} rows"
    end

    # Queries all four database models for their identifiers
    # @return [Hash] Hash with Sets for each model
    def query_database_models
      puts "[#{Time.zone.now}]   Querying Veteran::Service::Representative..."
      veteran_reps = Set.new(Veteran::Service::Representative.pluck(:representative_id).map(&:to_s))

      puts "[#{Time.zone.now}]   Querying AccreditedIndividual..."
      accredited_individuals = Set.new(AccreditedIndividual.pluck(:registration_number).map(&:to_s))

      puts "[#{Time.zone.now}]   Querying Veteran::Service::Organization..."
      veteran_orgs = Set.new(Veteran::Service::Organization.pluck(:poa).map { |p| p.to_s.strip.upcase })

      puts "[#{Time.zone.now}]   Querying AccreditedOrganization..."
      accredited_orgs = Set.new(AccreditedOrganization.pluck(:poa_code).map { |p| p.to_s.strip.upcase })

      {
        veteran_reps:,
        accredited_individuals:,
        veteran_orgs:,
        accredited_orgs:
      }
    end

    # Performs all comparisons between file data and database models
    # @param file_data [Hash] File identifiers
    # @param db_data [Hash] Database model identifiers
    def perform_comparisons(file_data, db_data)
      file_individuals = file_data[:individuals]
      file_orgs = file_data[:organizations]

      compare_file_vs_veteran_rep(file_individuals, db_data)
      compare_file_vs_accredited_ind(file_individuals, db_data)
      compare_file_vs_veteran_org(file_orgs, db_data)
      compare_file_vs_accredited_org(file_orgs, db_data)

      puts "[#{Time.zone.now}]   ✓ All comparisons complete"
    end

    def compare_file_vs_veteran_rep(file_individuals, db_data)
      puts "[#{Time.zone.now}]   Comparing File vs Veteran::Service::Representative..."
      @results[:file_vs_veteran_rep] = {
        in_file_not_db: file_individuals - db_data[:veteran_reps],
        in_db_not_file: db_data[:veteran_reps] - file_individuals,
        in_both: file_individuals & db_data[:veteran_reps]
      }
    end

    def compare_file_vs_accredited_ind(file_individuals, db_data)
      puts "[#{Time.zone.now}]   Comparing File vs AccreditedIndividual..."
      @results[:file_vs_accredited_ind] = {
        in_file_not_db: file_individuals - db_data[:accredited_individuals],
        in_db_not_file: db_data[:accredited_individuals] - file_individuals,
        in_both: file_individuals & db_data[:accredited_individuals]
      }
    end

    def compare_file_vs_veteran_org(file_orgs, db_data)
      puts "[#{Time.zone.now}]   Comparing File vs Veteran::Service::Organization..."
      @results[:file_vs_veteran_org] = {
        in_file_not_db: file_orgs - db_data[:veteran_orgs],
        in_db_not_file: db_data[:veteran_orgs] - file_orgs,
        in_both: file_orgs & db_data[:veteran_orgs]
      }
    end

    def compare_file_vs_accredited_org(file_orgs, db_data)
      puts "[#{Time.zone.now}]   Comparing File vs AccreditedOrganization..."
      @results[:file_vs_accredited_org] = {
        in_file_not_db: file_orgs - db_data[:accredited_orgs],
        in_db_not_file: db_data[:accredited_orgs] - file_orgs,
        in_both: file_orgs & db_data[:accredited_orgs]
      }
    end

    # Prints detailed comparison results
    def print_results
      puts "\n#{'=' * 80}"
      puts 'DETAILED COMPARISON RESULTS'
      puts "#{'=' * 80}\n\n"

      print_individual_comparison('File vs Veteran::Service::Representative', @results[:file_vs_veteran_rep])
      puts "\n#{'-' * 80}\n\n"

      print_individual_comparison('File vs AccreditedIndividual', @results[:file_vs_accredited_ind])
      puts "\n#{'-' * 80}\n\n"

      print_organization_comparison('File vs Veteran::Service::Organization', @results[:file_vs_veteran_org])
      puts "\n#{'-' * 80}\n\n"

      print_organization_comparison('File vs AccreditedOrganization', @results[:file_vs_accredited_org])
    end

    # Prints results for a single individual comparison
    # @param title [String] Comparison title
    # @param comparison [Hash] Comparison results with :in_file_not_db, :in_db_not_file, :in_both
    def print_individual_comparison(title, comparison)
      puts "#{title}:"
      puts "  In both: #{comparison[:in_both].size}"
      puts "  In file but not in DB: #{comparison[:in_file_not_db].size}"
      puts "  In DB but not in file: #{comparison[:in_db_not_file].size}"

      if comparison[:in_file_not_db].any?
        puts "\n  Registration numbers in FILE but NOT in DB (showing first 50):"
        comparison[:in_file_not_db].sort.first(50).each { |id| puts "    #{id}" }
        puts "    ... (#{comparison[:in_file_not_db].size - 50} more)" if comparison[:in_file_not_db].size > 50
      end

      if comparison[:in_db_not_file].any?
        puts "\n  Registration numbers in DB but NOT in FILE (showing first 50):"
        comparison[:in_db_not_file].sort.first(50).each { |id| puts "    #{id}" }
        puts "    ... (#{comparison[:in_db_not_file].size - 50} more)" if comparison[:in_db_not_file].size > 50
      end
    end

    # Prints results for a single organization comparison
    # @param title [String] Comparison title
    # @param comparison [Hash] Comparison results with :in_file_not_db, :in_db_not_file, :in_both
    def print_organization_comparison(title, comparison)
      puts "#{title}:"
      puts "  In both: #{comparison[:in_both].size}"
      puts "  In file but not in DB: #{comparison[:in_file_not_db].size}"
      puts "  In DB but not in file: #{comparison[:in_db_not_file].size}"

      if comparison[:in_file_not_db].any?
        puts "\n  POA codes in FILE but NOT in DB:"
        comparison[:in_file_not_db].sort.each { |poa| puts "    #{poa}" }
      end

      if comparison[:in_db_not_file].any?
        puts "\n  POA codes in DB but NOT in FILE:"
        comparison[:in_db_not_file].sort.each { |poa| puts "    #{poa}" }
      end
    end
  end
end
# rubocop:enable Rails/Output
