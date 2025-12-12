#!/usr/bin/env ruby
# frozen_string_literal: true

# Module Extraction Readiness Analysis
# Helps identify which modules are ready to be extracted into separate apps

require 'json'

class ExtractionAnalyzer
  MODULES_DIR = './modules'

  def initialize
    @results = {}
  end

  def analyze
    puts "🔍 Analyzing modules for extraction readiness..."
    puts "=" * 80
    puts

    module_dirs.each do |module_dir|
      module_name = File.basename(module_dir)
      @results[module_name] = analyze_module(module_dir, module_name)
    end

    generate_report
  end

  private

  def module_dirs
    Dir.glob("#{MODULES_DIR}/*").select { |f| File.directory?(f) }.sort
  end

  def analyze_module(module_dir, module_name)
    {
      name: module_name,
      score: 0,
      readiness: 'Unknown',
      dependencies: find_dependencies(module_dir),
      shared_models: find_shared_model_usage(module_dir),
      external_api_calls: find_external_apis(module_dir),
      database_usage: analyze_database_usage(module_dir),
      sidekiq_jobs: find_sidekiq_jobs(module_dir),
      authentication: uses_authentication?(module_dir),
      file_uploads: uses_file_uploads?(module_dir),
      redis_cache: uses_redis?(module_dir),
      complexity: calculate_complexity(module_dir)
    }
  end

  def find_dependencies(module_dir)
    deps = {
      requires_main_app: false,
      requires_other_modules: [],
      uses_lib_classes: [],
      uses_app_classes: []
    }

    Dir.glob("#{module_dir}/**/*.rb").each do |file|
      content = File.read(file)

      # Check for requires from main app
      if content.match?(/require\s+['"](?!#{File.basename(module_dir)})/)
        deps[:requires_main_app] = true
      end

      # Check for other module references
      content.scan(/(\w+)::\w+/) do |match|
        module_ref = match[0]
        next if module_ref == File.basename(module_dir).split('_').map(&:capitalize).join
        deps[:requires_other_modules] << module_ref unless deps[:requires_other_modules].include?(module_ref)
      end

      # Check for lib/ usage
      content.scan(/require\s+['"]([^'"]+)['"]/) do |req|
        if req[0].start_with?('common/', 'va_notify/', 'evss/', 'bgs/', 'mpi/')
          deps[:uses_lib_classes] << req[0]
        end
      end

      # Check for app/ class usage
      if content.match?(/User\.|Session\.|FormAttachment|InProgressForm/)
        deps[:uses_app_classes] << content.scan(/\b(User|Session|FormAttachment|InProgressForm)\b/).flatten.uniq
      end
    end

    deps[:uses_app_classes] = deps[:uses_app_classes].flatten.uniq
    deps[:uses_lib_classes] = deps[:uses_lib_classes].uniq
    deps[:requires_other_modules] = deps[:requires_other_modules].uniq

    deps
  end

  def find_shared_model_usage(module_dir)
    shared_models = []

    Dir.glob("#{module_dir}/**/*.rb").each do |file|
      content = File.read(file)

      # Common shared models
      %w[User Account InProgressForm SavedClaim FormAttachment].each do |model|
        if content.match?(/\b#{model}\b/)
          shared_models << model unless shared_models.include?(model)
        end
      end
    end

    shared_models
  end

  def find_external_apis(module_dir)
    apis = []

    Dir.glob("#{module_dir}/**/*.rb").each do |file|
      content = File.read(file)

      # Look for service configurations
      if content.match?(/EVSS|BGS|MPI|VAOS|Lighthouse|VBA|MHV/)
        apis << content.scan(/\b(EVSS|BGS|MPI|VAOS|Lighthouse|VBA|MHV)\b/).flatten.uniq
      end

      # Look for Faraday connections
      if content.match?(/Faraday\.new|Faraday\.get|Faraday\.post/)
        apis << 'Custom HTTP Client'
      end
    end

    apis.flatten.uniq
  end

  def analyze_database_usage(module_dir)
    usage = {
      has_migrations: Dir.exist?(File.join(module_dir, 'db', 'migrate')),
      migration_count: Dir.glob("#{module_dir}/db/migrate/*.rb").length,
      has_models: Dir.glob("#{module_dir}/app/models/**/*.rb").any?,
      model_count: Dir.glob("#{module_dir}/app/models/**/*.rb").length,
      uses_activerecord: false
    }

    Dir.glob("#{module_dir}/**/*.rb").each do |file|
      if File.read(file).match?(/ActiveRecord::Base|ApplicationRecord/)
        usage[:uses_activerecord] = true
        break
      end
    end

    usage
  end

  def find_sidekiq_jobs(module_dir)
    jobs = Dir.glob("#{module_dir}/app/sidekiq/**/*_job.rb") +
           Dir.glob("#{module_dir}/app/workers/**/*_worker.rb")

    {
      has_jobs: jobs.any?,
      job_count: jobs.length,
      job_names: jobs.map { |j| File.basename(j, '.rb') }
    }
  end

  def uses_authentication?(module_dir)
    Dir.glob("#{module_dir}/**/*.rb").any? do |file|
      File.read(file).match?(/authenticate|current_user|@current_user|session\[:token\]/)
    end
  end

  def uses_file_uploads?(module_dir)
    Dir.glob("#{module_dir}/**/*.rb").any? do |file|
      File.read(file).match?(/CarrierWave|upload|file_data|FormAttachment/)
    end
  end

  def uses_redis?(module_dir)
    Dir.glob("#{module_dir}/**/*.rb").any? do |file|
      File.read(file).match?(/Redis|REDIS|\.cache|Rails\.cache/)
    end
  end

  def calculate_complexity(module_dir)
    {
      controllers: Dir.glob("#{module_dir}/app/controllers/**/*.rb").length,
      models: Dir.glob("#{module_dir}/app/models/**/*.rb").length,
      services: Dir.glob("#{module_dir}/app/services/**/*.rb").length,
      jobs: Dir.glob("#{module_dir}/app/sidekiq/**/*.rb").length,
      total_files: Dir.glob("#{module_dir}/**/*.rb").length,
      loc: count_lines_of_code(module_dir)
    }
  end

  def count_lines_of_code(module_dir)
    total = 0
    Dir.glob("#{module_dir}/**/*.rb").each do |file|
      total += File.readlines(file).count { |line| !line.strip.empty? && !line.strip.start_with?('#') }
    end
    total
  end

  def generate_report
    puts "\n📊 EXTRACTION READINESS REPORT"
    puts "=" * 80
    puts

    # Score each module
    @results.each do |name, data|
      score = calculate_extraction_score(data)
      data[:score] = score
      data[:readiness] = readiness_level(score)
    end

    # Sort by readiness
    sorted = @results.sort_by { |_k, v| -v[:score] }

    # Easy wins (highest scores)
    easy_wins = sorted.select { |_k, v| v[:score] >= 70 }
    moderate = sorted.select { |_k, v| v[:score] >= 40 && v[:score] < 70 }
    difficult = sorted.select { |_k, v| v[:score] < 40 }

    puts "🟢 EASY WINS (Ready for extraction) - Score >= 70"
    puts "-" * 80
    easy_wins.each { |name, data| print_module_summary(name, data) }
    puts

    puts "🟡 MODERATE EFFORT - Score 40-69"
    puts "-" * 80
    moderate.each { |name, data| print_module_summary(name, data) }
    puts

    puts "🔴 DIFFICULT (High coupling) - Score < 40"
    puts "-" * 80
    difficult.each { |name, data| print_module_summary(name, data) }
    puts

    # Detailed breakdown for top candidates
    puts "\n📋 DETAILED BREAKDOWN - TOP 5 CANDIDATES"
    puts "=" * 80
    sorted.first(5).each do |name, data|
      print_detailed_analysis(name, data)
    end

    # Save JSON report
    File.write('extraction_analysis.json', JSON.pretty_generate(@results))
    puts "\n✓ Detailed analysis saved to extraction_analysis.json"
  end

  def calculate_extraction_score(data)
    score = 100

    # Penalties for coupling
    score -= 15 if data[:dependencies][:requires_main_app]
    score -= 10 * data[:dependencies][:requires_other_modules].length
    score -= 5 * data[:shared_models].length
    score -= 10 if data[:database_usage][:uses_activerecord] && data[:database_usage][:model_count] == 0
    score -= 5 * data[:dependencies][:uses_app_classes].length
    score -= 3 * data[:dependencies][:uses_lib_classes].length

    # Bonuses for independence
    score += 10 if data[:database_usage][:has_migrations] && data[:database_usage][:model_count] > 0
    score += 5 if data[:external_api_calls].any?
    score += 10 if !data[:authentication] || data[:complexity][:controllers] <= 5

    # Complexity penalties
    score -= 5 if data[:complexity][:loc] > 5000
    score -= 3 if data[:sidekiq_jobs][:job_count] > 5

    [score, 0].max # Don't go below 0
  end

  def readiness_level(score)
    case score
    when 70..100 then 'High - Easy Win'
    when 40..69 then 'Moderate - Some Refactoring Needed'
    when 0..39 then 'Low - Significant Refactoring Required'
    else 'Unknown'
    end
  end

  def print_module_summary(name, data)
    puts "  #{name.ljust(40)} | Score: #{data[:score].to_s.rjust(3)} | LOC: #{data[:complexity][:loc].to_s.rjust(5)}"

    # Key blockers
    blockers = []
    blockers << "#{data[:shared_models].length} shared models" if data[:shared_models].any?
    blockers << "#{data[:dependencies][:requires_other_modules].length} module deps" if data[:dependencies][:requires_other_modules].any?
    blockers << "Main app coupling" if data[:dependencies][:requires_main_app]

    puts "       Blockers: #{blockers.join(', ')}" if blockers.any?
  end

  def print_detailed_analysis(name, data)
    puts "\n### #{name} (Score: #{data[:score]} - #{data[:readiness]})"
    puts "-" * 80

    puts "Complexity:"
    puts "  - Lines of Code: #{data[:complexity][:loc]}"
    puts "  - Controllers: #{data[:complexity][:controllers]}"
    puts "  - Models: #{data[:complexity][:models]}"
    puts "  - Services: #{data[:complexity][:services]}"
    puts "  - Background Jobs: #{data[:sidekiq_jobs][:job_count]}"

    puts "\nDependencies:"
    puts "  - Requires main app: #{data[:dependencies][:requires_main_app] ? '❌ YES' : '✅ NO'}"

    other_modules = data[:dependencies][:requires_other_modules].join(', ')
    puts "  - Other modules: #{other_modules.empty? ? 'None' : other_modules}"

    shared_models = data[:shared_models].join(', ')
    puts "  - Shared models: #{shared_models.empty? ? 'None' : shared_models}"

    app_classes = data[:dependencies][:uses_app_classes].join(', ')
    puts "  - App classes: #{app_classes.empty? ? 'None' : app_classes}"

    puts "\nDatabase:"
    puts "  - Has migrations: #{data[:database_usage][:has_migrations] ? '✅' : '❌'}"
    puts "  - Model count: #{data[:database_usage][:model_count]}"

    puts "\nExternal Services:"
    apis = data[:external_api_calls].join(', ')
    puts "  - APIs: #{apis.empty? ? 'None' : apis}"

    puts "\nFeatures:"
    puts "  - Authentication: #{data[:authentication] ? '✅' : '❌'}"
    puts "  - File Uploads: #{data[:file_uploads] ? '✅' : '❌'}"
    puts "  - Redis/Cache: #{data[:redis_cache] ? '✅' : '❌'}"

    puts "\n" + "~" * 80
  end
end

if __FILE__ == $0
  analyzer = ExtractionAnalyzer.new
  analyzer.analyze
end