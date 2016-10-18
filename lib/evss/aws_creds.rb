# frozen_string_literal: true
require 'net/http'

module EVSS
  class AwsCreds
    METADATA_ENDPOINT = 'http://169.254.169.254/latest/meta-data/iam/security-credentials/CloudWatchRole/'

    def self.fetch(fetch_from_remote = false)
      if fetch_from_remote
        meta = JSON.parse Net::HTTP.get(URI.parse(METADATA_ENDPOINT))
        {
          aws_access_key_id: meta['AccessKeyId'],
          aws_secret_access_key: meta['SecretAccessKey']
        }
      end
    end
  end
end
