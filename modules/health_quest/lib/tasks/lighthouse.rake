# frozen_string_literal: true

# Rake tasks to create and update questionnaires in PGD

# rubocop:disable all
namespace :lighthouse do
  namespace :pgd do
    namespace :questionnaires do
      desc 'Create new Questionnaire'
      task :create, [:github_questionnaire] => [:environment, :confirm] do |task, args|
        puts "IN THE #{Rails.env} ENVIRONMENT"
        puts "SETTINGS FILE: #{Settings.vsp_environment}\n\n"

        # we're not going to run these rake tasks in the vets-api development environment
        # since the dev-api.va.gov actually runs in production mode and we don't want to
        # unintentionally communicate with the Lighthouse production environment
        abort('Please do not run this rake task in dev.va.gov as the vets-api runs in production mode!') if Settings.vsp_environment == 'development'

        # pre-pending constants with HQ_RAKE so that we're not accidentally re-initializing
        # constants that may have been set elsewhere in the engine
        # HQ_RAKE_USER_ICN = '1008882029V85179'
        HQ_RAKE_API = 'pgd_api'
        HQ_RAKE_QUESTIONNAIRE_URI = '/services/pgd/v0/r4/Questionnaire'
        HQ_RAKE_GITHUB_PAGES_URL = 'https://dillo.github.io'

        def new_faraday_lighthouse_conn(token)
          Faraday.new(url: Settings.hqva_mobile.lighthouse.url, headers: { 'Content-Type' => 'application/fhir+json', 'Authorization' => "Bearer #{token}" }) do |f|
            f.request :retry
            f.response :json, content_type: /\bjson/
            f.adapter Faraday.default_adapter
          end
        end

        def new_faraday_github_conn
          Faraday.new(url: HQ_RAKE_GITHUB_PAGES_URL, headers: { 'Accept' => 'application/json' }) do |f|
            f.request :retry
            f.response :json, content_type: /\bjson/
            f.adapter Faraday.default_adapter
          end
        end

        abort("PLEASE PASS A VALID .json FILE! #{args[:github_questionnaire]} is not a valid file format!") unless args[:github_questionnaire] =~ /^\S+.json/

        # spoof logged in user and their ICN
        Foo = Struct.new(:icn)
        current_user = Foo.new('foobaricn')

        # grab our authentication token from Lighthouse
        begin
          access_token = HealthQuest::Lighthouse::Token.build(user: current_user, api: HQ_RAKE_API)

          def access_token.post_params
            hash = {
              grant_type: lighthouse.grant_type,
              client_assertion_type: lighthouse.client_assertion_type,
              client_assertion: claims_token,
              scope: 'system/Questionnaire.read system/Questionnaire.write'
            }

            URI.encode_www_form(hash)
          end

          token_response = access_token&.fetch
        rescue StandardError => e
          puts "LIGHTHOUSE TOKEN FETCH FAILED\n\n"
          abort "#{e.message}"
        end

        token = token_response&.access_token

        # exit our task if there is no token
        abort "LIGHTHOUSE TOKEN FETCH FAILED. QUESTIONNAIRE NOT CREATED ###\n\n #{token_response&.inspect}" if token.blank?

        # create a new Faraday(http client) object for Lighthouse
        conn = new_faraday_lighthouse_conn(token)

        # create a new Faraday(http client) object for Github
        github_conn = new_faraday_github_conn

        # GET the questionnaire JSON from Github
        begin
          github_response = github_conn.get("/#{args[:github_questionnaire]}")
        rescue StandardError => e
          puts 'GITHUB GET REQUEST FAILED'
          abort "#{e.message}\n\n"
        end

        # exit our task if Questionnaire is empty
        abort "QUESTIONNAIRE IS EMPTY ###\n\n #{github_response&.inspect}" if github_response&.body.blank?
        abort "THIS QUESTIONNAIRE HAS ALREADY BEEN CREATED. USE THE UPDATE TASK IF YOU WISH TO MODIFY IT!\n\n" if github_response&.body.has_key?('id')

        puts "THE QUESTIONNAIRE DATA TO BE POSTED TO LIGHTHOUSE\n\n"
        puts github_response&.body
        puts "\n\n"

        # POST the questionnaire body to the Lighthouse PGD
        begin
          response = conn.post(HQ_RAKE_QUESTIONNAIRE_URI) do |req|
            req.body = github_response&.body&.to_json
          end
        rescue StandardError => e
          puts 'LIGHTHOUSE POST REQUEST FAILED'
          abort "#{e.message}\n\n"
          puts "TOKEN RESPONSE\n\n"
          puts "#{token_response&.inspect}\n\n"
        end

        # determine output message depending on response status
        if  (200..204).include?(response&.status)
          puts "SUCCESSFULLY CREATED QUESTIONNAIRE\n\n"
        else
          puts "QUESTIONNAIRE CREATE FAILED\n\n"
          puts "TOKEN RESPONSE\n\n"
          puts "#{token_response&.inspect}\n\n"
        end

        # print out the response body
        puts "RESPONSE BODY\n\n"
        puts response&.body
        puts "\n\n"
        puts "PLEASE SET THE `id` #{response&.body&.fetch('id', 'NA')} on your GITHUB PAGES QUESTIONNAIRE!"
      end

      # +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

      desc 'Update Questionnaire'
      task :update, [:github_questionnaire] => [:environment, :confirm] do |task, args|
        puts "IN THE #{Rails.env} ENVIRONMENT"
        puts "SETTINGS FILE: #{Settings.vsp_environment}\n\n"

        # we're not going to run these rake tasks in the vets-api development environment
        # since the dev-api.va.gov actually runs in production mode and we don't want to
        # unintentionally communicate with the Lighthouse production environment
        abort('Please do not run this rake task in dev.va.gov as the vets-api runs in production mode!') if Settings.vsp_environment == 'development'

        # pre-pending constants with HQ_RAKE so that we're not accidentally re-initializing
        # constants that may have been set elsewhere in the engine
        # HQ_RAKE_USER_ICN = '1008882029V85179'
        HQ_RAKE_API = 'pgd_api'
        HQ_RAKE_QUESTIONNAIRE_URI = '/services/pgd/v0/r4/Questionnaire'
        HQ_RAKE_GITHUB_PAGES_URL = 'https://dillo.github.io'

        def new_faraday_lighthouse_conn(token)
          Faraday.new(url: Settings.hqva_mobile.lighthouse.url, headers: { 'Content-Type' => 'application/fhir+json', 'Authorization' => "Bearer #{token}" }) do |f|
            f.request :retry
            f.response :json, content_type: /\bjson/
            f.adapter Faraday.default_adapter
          end
        end

        def new_faraday_github_conn
          Faraday.new(url: HQ_RAKE_GITHUB_PAGES_URL, headers: { 'Accept' => 'application/json' }) do |f|
            f.request :retry
            f.response :json, content_type: /\bjson/
            f.adapter Faraday.default_adapter
          end
        end

        abort("PLEASE PASS A VALID .json FILE! #{args[:github_questionnaire]} is not a valid file format!") unless args[:github_questionnaire] =~ /^\S+.json/

        # spoof logged in user and their ICN
        Foo = Struct.new(:icn)
        current_user = Foo.new('foobaricn')

        # create a new Faraday(http client) object for Github
        github_conn = new_faraday_github_conn

        # GET the questionnaire JSON from Github
        begin
          github_response = github_conn.get("/#{args[:github_questionnaire]}")
        rescue StandardError => e
          puts 'GITHUB GET REQUEST FAILED'
          abort "#{e.message}\n\n"
        end

        # exit our task if Questionnaire is empty
        abort "QUESTIONNAIRE IS EMPTY ###\n\n #{github_response&.inspect}" if github_response&.body.blank?

        puts "THE QUESTIONNAIRE DATA TO BE `PUT` TO LIGHTHOUSE\n\n"
        puts github_response&.body
        puts "\n\n"

        # get the questionnaire id of the questionnaire we wish to update in Lighthouse
        questionnaire_id = github_response&.body.fetch('id')

        # exit our task if Questionnaire is empty
        abort "QUESTIONNAIRE DOES NOT HAVE AN `id` FIELD! ###\n\n" if questionnaire_id.blank?

        # grab our authentication token from Lighthouse
        begin
          access_token = HealthQuest::Lighthouse::Token.build(user: current_user, api: HQ_RAKE_API)

          def access_token.post_params
            hash = {
              grant_type: lighthouse.grant_type,
              client_assertion_type: lighthouse.client_assertion_type,
              client_assertion: claims_token,
              scope: 'system/Questionnaire.read system/Questionnaire.write'
            }

            URI.encode_www_form(hash)
          end

          token_response = access_token&.fetch
        rescue StandardError => e
          puts "LIGHTHOUSE TOKEN FETCH FAILED\n\n"
          abort "#{e.message}"
        end

        token = token_response&.access_token

        # exit our task if there is no token
        abort "LIGHTHOUSE TOKEN FETCH FAILED. QUESTIONNAIRE NOT UPDATED ###\n\n #{token_response&.inspect}" if token.blank?

        # create a new Faraday(http client) object for Lighthouse
        conn = new_faraday_lighthouse_conn(token)

        # GET the questionnaire from Lighthouse that we wish to update
        begin
          get_response = conn.get("#{HQ_RAKE_QUESTIONNAIRE_URI}/#{questionnaire_id}")
        rescue StandardError => e
          puts 'LIGHTHOUSE GET REQUEST FAILED'
          abort "#{e.message}\n\n"
          puts "TOKEN RESPONSE\n\n"
          puts "#{token_response&.inspect}\n\n"
        end

        abort "THE QUESTIONNAIRE COULD NOT BE FOUND OR YOUR TOKEN DOES NOT HAVE ACCESS TO IT!\n\n" if (400..404).include?(get_response.status)

        # PUT the updated questionnaire and update the resource
        begin
          put_response = conn.put("#{HQ_RAKE_QUESTIONNAIRE_URI}/#{questionnaire_id}") do |req|
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
