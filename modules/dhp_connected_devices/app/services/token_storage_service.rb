# frozen_string_literal: true

require 'fileutils'

class TokenStorageError < StandardError; end

class TokenStorageService
  ##
  # Uses s3 client to store tokens for the spark token schema
  # Gracefully handles runtime errors
  #
  # @return [boolean]
  # @raise TokenStorageError
  def store_tokens(current_user, device_key, tokens_hash)
    payload_json = unpack_payload(tokens_hash)
    return store_locally(current_user, device_key, payload_json) unless vsp_env_exists

    resp = s3_client.put_object(
      bucket: Settings.dhp.s3.bucket,
      key: "icn=#{current_user.icn}/device=#{device_key}/tokens.json",
      body: payload_json
    )
    resp.etag ? true : raise('Error when storing token to S3')
  rescue => e
    raise TokenStorageError, "Token storage failed for user with ICN: #{current_user.icn}, Error: #{e.message}"
  end

  private

  ##
  # Package tokens to match Spark's token schema
  #
  # @return [json]
  # @raise TokenStorageError
  def unpack_payload(tokens_hash)
    unpacked_token = {
      "payload": {
        "access_token": tokens_hash[:access_token],
        "refresh_token": tokens_hash[:refresh_token],
        "scope": tokens_hash[:scope].gsub(' ', ','),
        "expires_in": tokens_hash[:expires_in],
        "received_at": Time.now.utc.strftime('%s%L')
      }
    }
    JSON.dump(unpacked_token)
  rescue => e
    raise TokenStorageError, "Error when unpacking token: #{tokens_hash}, #{e}"
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      region: Settings.dhp.s3.region,
      access_key_id: Settings.dhp.s3.aws_access_key_id,
      secret_access_key: Settings.dhp.s3.aws_secret_access_key
    )
  end

  def vsp_env_exists
    !Settings.vsp_environment.nil?
  end

  ##
  # Stores tokens as a read-write file according to the Spark schema
  # @return [boolean]
  # @raise [TokenStorageError]
  def store_locally(current_user, device_key, payload_json)
    directory_path = "#{::Rails.root}/modules/dhp_connected_devices/tmp/" \
                     "icn=#{current_user.icn}/device=#{device_key}/tokens.json"

    begin
      dirname = File.dirname(directory_path)
      FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
      File.open(directory_path, 'w+') do |file|
        file.write(payload_json)
      end
      true
    rescue => e
      raise TokenStorageError, "Error with storing locally: #{payload_json}, #{e}"
    end
  end
end
