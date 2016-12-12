# frozen_string_literal: true
require 'csv'
require 'load_csv_helper'

namespace :gibct do
  desc 'Clear and load institutions from CSV, e.g. rake gibct:load_csv[db/gibct_data.csv]'
  task :load_csv, [:csv_file] => [:environment, :build_tables] do |_t, args|
    puts "Loading #{args[:csv_file]} ... "
    count = 0

    ActiveRecord::Base.transaction do
      opts = {
        headers: true,
        encoding: 'iso-8859-1:utf-8',
        header_converters: :symbol
      }
      CSV.foreach(args[:csv_file], opts) do |row|
        count += 1

        row = LoadCsvHelper.convert(row.to_hash)
        unless (i = Institution.create(row)).persisted?
          reason = i.errors.to_a.join(', ')

          puts "\nRecord: #{count}: #{i.institution} not created! - #{reason}\n"
          Rails.logger.error "Record: #{count}, #{i.institution} not created! - #{reason}"
        end

        print "\r Records: #{count}"
        Rails.logger.info "==== GIBCT Records Imported: #{count}"
      end
    end

    puts "\n==== load_csv done!\n\n\n"
  end

  task build_tables: :environment do
    if Rails.env.intern == :development
      puts "Clearing development logs...\n"
      Rake::Task['log:clear'].invoke
    end

    puts 'Delete records in Institution in preparation for loading...'
    Institution.delete_all

    puts 'Delete records in InstitutionType in preparation for loading...'
    InstitutionType.delete_all

    puts 'Running migrations ...'
    Rake::Task['db:migrate'].invoke

    puts "\n==== build_tables done!\n\n\n"
  end
end
