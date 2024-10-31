# frozen_string_literal: true

module Vye
  module DGIB
    class Configuration < Common::Client::Configuration::REST
      def connection
        # one of the issues we ran into was with self signed certificates being in the keychain. VA signs it's
        # own certificates, so we need to inlude the ones used.
        # this command identified the ones we needed to include:
        # openssl s_client -connect dgi-afs003-vaapi.np.afsp.io:443 -showcerts
        # You have to scroll through the output and find the ones it complains about.
        # There were two of them and in order for this to work right, they neeeded to be concatenated into one file.
        # cat VA-Internal-S2-ICA11.crt VA-Internal-S2-RCA2.crt > VA-Internal-S2-ICA11-RCA2-combined-cert.pem
        # It was necesary to check the file and carriage return it because it didn't line break properly at the
        # end of the first certificate and the start of the second.
        # Not sure if the order of the concatenation matters here.

        # Platform has a link for where the individual certs can be downloaded here
        # http://aia.pki.va.gov/PKI/AIA/VA/
        # And a script here that can be used to download and install all of them.
        # https://github.com/department-of-veterans-affairs/vsp-platform-infrastructure/blob/main/packer/eks/scripts/import-va-certs.sh
        # The script needs tweaking for Ubuntu.
        # Remove line 40(ish) as it's for RHEL and will cause the script to crash.
        # \cp -f "${cert}.crt" /etc/pki/ca-trust/source/anchors/ # for RHEL-based systems
        # line 43(ish) should be changed from this: update-ca-trust to this: update-ca-certificates
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use :breakers
          faraday.ssl[:ca_file] = 'modules/vye/spec/fixtures/ICA11-RCA2-combined-cert.pem'
          # faraday.ssl[:ca_file] =  'modules/vye/spec/fixtures/RCA2-ICA11-combined-cert.pem'
          faraday.request :json
          faraday.use      Faraday::Response::RaiseError
          faraday.response :betamocks if mock_enabled?
          faraday.response :snakecase, symbolize: false
          faraday.response :json, content_type: /\bjson/ # ensures only json content types parsed
          faraday.adapter Faraday.default_adapter
        end
      end

      def base_path
        Settings.dgi.vye.vets.url.to_s
      end

      def service_name
        'DGI'
      end

      def mock_enabled?
        Settings.dgi.vye.vets.mock || false
      end
    end
  end
end
