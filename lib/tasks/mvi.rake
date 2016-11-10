# frozen_string_literal: true
require 'csv'
require 'json'

namespace :mvi do
  desc 'Given user attributes, run a find candidate query'
  task find: :environment do
    unless valid_user_vars
      raise ArgumentError, 'Run the task with all required attributes: bundle exec rake mvi:find first_name="John"
middle_name="W" last_name="Smith" birth_date="1945-01-25" gender="M" ssn="555443333"'
    end

    begin
      user = find_user(
        first_name: ENV['first_name'],
        middle_name: ENV['middle_name'],
        last_name: ENV['last_name'],
        birth_date: ENV['birth_date'],
        gender: ENV['gender'],
        ssn: ENV['ssn'],
        email: 'foo@bar.og'
      )
      puts user.to_json
    rescue => e
      puts "User query failed: #{e.message}"
    end
  end

  # CSV headers (other values are ok but below are required)
  # first_name, middle_name, last_name, gender, birth_date, ssn, email
  #
  desc 'Given a path to a CSV of users, run a find candidate query against all of them'
  task find_all: :environment do
    unless ENV['csv']
      raise ArgumentError, 'Run the task with a CSV of users: bundle exec rake mvi:find_all csv=="./path/users.csv"'
    end

    users = []
    found_users = []
    CSV.foreach(
      ENV['csv'],
      headers: true, header_converters: :symbol, converters: :all
    ) do |row|
      users << Hash[row.headers[0..-1].zip(row.fields[0..-1])]
    end

    i = 0
    found = 0

    users.each do |u|
      i += 1
      begin
        puts "\nSearching for: #{u[:ssn]} - #{u[:first_name]} #{u[:last_name]}\n"
        user = find_user(u)
        found += 1
        puts "Found #{found} of #{i} users:\n\n"
        puts user.to_json
        found_users << user
      rescue => e
        puts "User query failed: #{e.message}"
      end
      puts "\n-----------------------------------------------------------------\n"
    end

    puts "\nDONE!\n"

    puts Oj.dump(found_users, mode: :compat)
  end
end

def valid_user_vars
  date_valid = validate_date(ENV['birth_date'])
  name_valid = ENV['first_name'] && ENV['middle_name'] && ENV['last_name']
  attrs_valid = ENV['gender'] && ENV['ssn']
  date_valid && name_valid && attrs_valid
end

def validate_date(s)
  raise ArgumentError, 'Date string must be of format YYYY-MM-DD' unless s =~ /\d{4}-\d{2}-\d{2}/
  Time.parse(s).utc
  true
rescue => e
  puts e.message
  false
end

def find_user(user_attrs)
  user = User.new(
    first_name: user_attrs[:first_name],
    last_name: user_attrs[:last_name],
    middle_name: user_attrs[:middle_name],
    birth_date: Time.parse(user_attrs[:birth_date]).utc,
    gender: user_attrs[:gender],
    ssn: user_attrs[:ssn],
    email: user_attrs[:email],
    uuid: SecureRandom.uuid,
    loa: {
      current: LOA::TWO,
      highest: LOA::THREE
    }
  )
  Decorators::MviUserDecorator.new(user).create
end
