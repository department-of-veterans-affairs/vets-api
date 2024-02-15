# frozen_string_literal: true

require 'faraday/retry'

# Rake tasks to create and update questionnaires in PGD

# rubocop:disable all
module HealthQuest::LighthouseRake
  class Questionnaire
    API = 'pgd_api'
    QUESTIONNAIRE_URI = '/services/pgd/v0/r4/Questionnaire'
    GITHUB_PAGES_URL = 'https://dillo.github.io'

    attr_reader :file_name

    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts)
      @file_name = opts[:file_name]
    end

    def build_token
      HealthQuest::Lighthouse::Token.build(user: current_user, api: API)
    end

    def dev_env?
      vsp_env == 'development'
    end

    def existing_questionnaire?(resp)
      resp&.body&.has_key?('id')
    end

    def github_conn
      conn(GITHUB_PAGES_URL, accept_header)
    end

    def lighthouse_conn(token)
      conn(lighthouse_url, lighthouse_headers(token))
    end

    def redefine_post_params(token_obj)
      token_obj.define_singleton_method(:post_params) do
        hash = {
          grant_type: lighthouse.grant_type,
          client_assertion_type: lighthouse.client_assertion_type,
          client_assertion: claims_token,
          scope: 'system/Questionnaire.read system/Questionnaire.write'
        }

        URI.encode_www_form(hash)
      end
    end

    def rails_env
      Rails.env
    end

    def questionnaire_uri
      QUESTIONNAIRE_URI
    end

    def vsp_env
      Settings.vsp_environment
    end

    def valid_file?
      file_name =~ /^\S+.json/
    end

    private

    def accept_header
      { 'Accept' => 'application/json' }
    end

    def conn(url, headers)
      Faraday.new(url: url, headers: headers) do |f|
        f.request :retry
        f.response :json, content_type: /\bjson/
        f.adapter Faraday.default_adapter
      end
    end

    def current_user
      rake_user = Struct.new(:icn)

      rake_user.new('foobaricn')
    end

    def lighthouse_headers(token)
      { 'Content-Type' => 'application/fhir+json', 'Authorization' => "Bearer #{token}" }
    end

    def lighthouse_url
      Settings.hqva_mobile.lighthouse.url
    end
  end
end

namespace :lighthouse do
  namespace :pgd do
    namespace :questionnaires do
      desc 'Create new Questionnaire'
      task :create, [:github_questionnaire] => [:environment, :confirm] do |task, args|
        quest = HealthQuest::LighthouseRake::Questionnaire.build(file_name: args[:github_questionnaire])

        puts "IN THE #{quest.rails_env} ENVIRONMENT"
        puts "SETTINGS FILE: #{quest.vsp_env}\n\n"

        # We're not going to run these rake tasks in the vets-api development environment
        # since the dev-api.va.gov actually runs in production mode and we don't want to
        # unintentionally communicate with the Lighthouse production environment
        abort('Please do not run this rake task in dev.va.gov as the vets-api runs in production mode!') if quest.dev_env?

        # Exit our task if a valid file extension is not passed in from the cmd line
        abort("PLEASE PASS A VALID .json FILE! #{quest.file_name} is not a valid file format!") unless quest.valid_file?

        # Grab our authentication token from Lighthouse
        token_response =
          begin
            quest.build_token.tap do |tok|
              quest.redefine_post_params(tok)
              tok.fetch
            end
          rescue StandardError => e
            puts "LIGHTHOUSE TOKEN FETCH FAILED\n\n"
            abort "#{e.message}"
          end

        token = token_response&.access_token

        # Exit our task if there is no token
        abort "LIGHTHOUSE TOKEN FETCH FAILED. QUESTIONNAIRE NOT CREATED ###\n\n #{token_response&.inspect}" if token.blank?

        # Create a new Faraday(http client) object for Lighthouse
        conn = quest.lighthouse_conn(token)

        # Create a new Faraday(http client) object for Github
        github_conn = quest.github_conn

        # GET the questionnaire JSON from Github
        github_response =
          begin
            github_conn.get("/#{quest.file_name}")
          rescue StandardError => e
            puts 'GITHUB GET REQUEST FAILED'
            abort "#{e.message}\n\n"
          end

        # Exit our task if Questionnaire is empty
        abort "QUESTIONNAIRE IS EMPTY ###\n\n #{github_response&.inspect}" if github_response&.body.blank?

        # Exit the task if the questionnaire exists
        abort "THIS QUESTIONNAIRE HAS ALREADY BEEN CREATED. USE THE UPDATE TASK IF YOU WISH TO MODIFY IT!\n\n" if quest.existing_questionnaire?(github_response)

        puts "THE QUESTIONNAIRE DATA TO BE POSTED TO LIGHTHOUSE\n\n"
        puts github_response&.body
        puts "\n\n"

        # POST the questionnaire body to the Lighthouse PGD
        response =
          begin
            conn.post(quest.questionnaire_uri) do |req|
              req.body = github_response&.body&.to_json
            end
          rescue StandardError => e
            puts 'LIGHTHOUSE POST REQUEST FAILED'
            abort "#{e.message}\n\n"
            puts "TOKEN RESPONSE\n\n"
            puts "#{token_response&.inspect}\n\n"
          end

        # Determine output message depending on response status
        if  (200..204).include?(response&.status)
          puts "SUCCESSFULLY CREATED QUESTIONNAIRE\n\n"
        else
          puts "QUESTIONNAIRE CREATE FAILED\n\n"
          puts "TOKEN RESPONSE\n\n"
          puts "#{token_response&.inspect}\n\n"
        end

        # Print out the response body
        puts "RESPONSE BODY\n\n"
        puts response&.body
        puts "\n\n"
        puts "PLEASE SET THE `id` #{response&.body&.fetch('id', 'NA')} on your GITHUB PAGES QUESTIONNAIRE!"
      end

      # +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

      desc 'Update Questionnaire'
      task :update, [:github_questionnaire] => [:environment, :confirm] do |task, args|
        quest = HealthQuest::LighthouseRake::Questionnaire.build(file_name: args[:github_questionnaire])

        puts "IN THE #{quest.rails_env} ENVIRONMENT"
        puts "SETTINGS FILE: #{quest.vsp_env}\n\n"

        # We're not going to run these rake tasks in the vets-api development environment
        # since the dev-api.va.gov actually runs in production mode and we don't want to
        # unintentionally communicate with the Lighthouse production environment
        abort('Please do not run this rake task in dev.va.gov as the vets-api runs in production mode!') if quest.dev_env?

        # Exit our task if a valid file extension is not passed in from the cmd line
        abort("PLEASE PASS A VALID .json FILE! #{quest.file_name} is not a valid file format!") unless quest.valid_file?

        # Create a new Faraday(http client) object for Github
        github_conn = quest.github_conn

        # GET the questionnaire JSON from Github
        github_response =
          begin
            github_conn.get("/#{quest.file_name}")
          rescue StandardError => e
            puts 'GITHUB GET REQUEST FAILED'
            abort "#{e.message}\n\n"
          end

        # Exit our task if Questionnaire is empty
        abort "QUESTIONNAIRE IS EMPTY ###\n\n #{github_response&.inspect}" if github_response&.body.blank?

        puts "THE QUESTIONNAIRE DATA TO BE `PUT` TO LIGHTHOUSE\n\n"
        puts github_response&.body
        puts "\n\n"

        # Get the questionnaire id of the questionnaire we wish to update in Lighthouse
        questionnaire_id = github_response&.body.fetch('id')

        # Exit our task if Questionnaire is empty
        abort "QUESTIONNAIRE DOES NOT HAVE AN `id` FIELD! ###\n\n" if questionnaire_id.blank?

        # Grab our authentication token from Lighthouse
        token_response =
          begin
            quest.build_token.tap do |tok|
              quest.redefine_post_params(tok)
              tok.fetch
            end
          rescue StandardError => e
            puts "LIGHTHOUSE TOKEN FETCH FAILED\n\n"
            abort "#{e.message}"
          end

        token = token_response&.access_token

        # Exit our task if there is no token
        abort "LIGHTHOUSE TOKEN FETCH FAILED. QUESTIONNAIRE NOT UPDATED ###\n\n #{token_response&.inspect}" if token.blank?

        # Create a new Faraday(http client) object for Lighthouse
        conn = quest.lighthouse_conn(token)

        # GET the questionnaire from Lighthouse that we wish to update
        get_response =
          begin
            conn.get("#{quest.questionnaire_uri}/#{questionnaire_id}")
          rescue StandardError => e
            puts 'LIGHTHOUSE GET REQUEST FAILED'
            abort "#{e.message}\n\n"
            puts "TOKEN RESPONSE\n\n"
            puts "#{token_response&.inspect}\n\n"
          end

        abort "THE QUESTIONNAIRE COULD NOT BE FOUND OR YOUR TOKEN DOES NOT HAVE ACCESS TO IT!\n\n" if (400..404).include?(get_response.status)

        # PUT the updated questionnaire and update the resource
        put_response =
          begin
            conn.put("#{quest.questionnaire_uri}/#{questionnaire_id}") do |req|
              req.body = github_response&.body&.to_json
            end
          rescue StandardError => e
            puts 'LIGHTHOUSE PUT REQUEST FAILED'
            abort "#{e.message}\n\n"
            puts "TOKEN RESPONSE\n\n"
            puts "#{token_response&.inspect}\n\n"
          end

        # determine output message depending on response status
        if  (200..204).include?(put_response&.status)
          puts "SUCCESSFULLY UPDATED QUESTIONNAIRE #{questionnaire_id}\n\n"
        else
          puts "FAILED TO UPDATE QUESTIONNAIRE #{questionnaire_id}\n\n"
          puts "TOKEN RESPONSE\n\n"
          puts "#{token_response&.inspect}\n\n"
        end

        # print out the response body
        puts "OLD QUESTIONNAIRE\n\n #{get_response&.body}\n\n"
        puts "UPDATED QUESTIONNAIRE\n\n #{put_response&.body}\n\n"
      end

      # +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

      desc 'Confirm Task Execution'
      task :confirm do
        confirm_token = rand(36**6).to_s(36)
        STDOUT.puts "ARE YOU SURE YOU WANT TO DO THIS? ENTER '#{confirm_token}' TO CONFIRM:"
        input = STDIN.gets.chomp

        abort "ABORTING RAKE TASK. YOU ENTERED #{input}" unless input == confirm_token
      end
    end
  end
end
# rubocop:enable all
