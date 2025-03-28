# frozen_string_literal: true

namespace :mockdata_synchronize do
  desc 'Iterate through mockdata records and update them with actual MPI calls'
  task :mpi_profile_icn, [:icn] => [:environment] do |_, args|
    require 'net/http'
    require 'uri'
    require 'openssl'

    def create_cache_from_profile(icn, file_path)
      response = create_curl(icn)
      save_response(response, file_path)
    end

    def save_response(env, file_path)
      response = {
        method: :post,
        body: Nokogiri::XML(env.body).root.to_xml,
        headers: {
          connection: 'close',
          date: Time.zone.now.strftime('%a, %d %b %Y %H:%M:%S %Z'),
          'content-type' => 'text/xml'
        },
        status: 200
      }

      File.write(file_path, response.to_yaml)
    end

    def create_curl(icn)
      uri = URI.parse(IdentitySettings.mvi.url)
      request = Net::HTTP::Post.new(uri)
      request.content_type = 'text/xml;charset=UTF-8'
      request['Connection'] = 'close'
      request['User-Agent'] = 'Vets.gov Agent'
      request['Soapaction'] = 'PRPA_IN201305UV02'
      template = Liquid::Template.parse(File.read(File.join('config',
                                                            'mpi_schema',
                                                            'mpi_find_person_icn_template.xml')))
      xml = template.render!('icn' => icn)
      request.body = xml
      req_options = { use_ssl: uri.scheme == 'https', verify_mode: OpenSSL::SSL::VERIFY_NONE }
      Net::HTTP.start(uri.hostname, uri.port, req_options) { |http| http.request(request) }
    end

    def update_mpi_record_for_icn(icn, file_name)
      create_cache_from_profile(icn, file_name)
      puts "Updated record for #{file_name}"
    end

    if args[:icn].present?
      icn = args[:icn]
      file_name = "#{Settings.betamocks.cache_dir}/mvi/profile_icn/#{icn}.yml"
      update_mpi_record_for_icn(icn, file_name)
    else
      Dir.glob("#{Settings.betamocks.cache_dir}/mvi/profile_icn/*.yml").each do |file_name|
        icn = File.basename(file_name, '.yml')
        update_mpi_record_for_icn(icn, file_name)
        sleep 1
      end
    end
  end
end
