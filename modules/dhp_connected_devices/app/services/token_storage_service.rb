# frozen_string_literal: true

require 'fileutils'

class TokenStorageError < StandardError; end
class TokenRetrievalError < StandardError; end
class TokenDeletionError < StandardError; end

class TokenStorageService
  ##
  # Store tokens in S3 or locally in json format
  # Gracefully handles runtime errors
  #
  # @return [boolean]
  # @raise TokenStorageError
  def store_tokens(current_user, device_key, tokens_hash)
    payload_json = unpack_payload(tokens_hash)
    return store_locally(current_user, device_key, payload_json) if vsp_env_local || vsp_env_test

    resp = s3_client.put_object(
      bucket: Settings.dhp.s3.bucket,
      key: "#{generate_prefix(current_user, device_key)}tokens.json",
      body: payload_json
    )
    resp.etag ? true : raise('Error when storing token to S3')
  rescue => e
    raise TokenStorageError, "Token storage failed for user with ICN: #{current_user.icn}, Error: #{e.message}"
  end

  ##
  # Retrieves token json file from S3 or locally and converts it to a hash
  #
  # @return [Hash]
  # @raise TokenRetrievalError
  def get_token(current_user, device_key)
    return get_locally(current_user, device_key) if vsp_env_local || vsp_env_test

    files_resp = lists_files_in_bucket(generate_prefix(current_user, device_key))
    token_file_name = select_token_file(files_resp.contents).key
    token_as_get_object_output = get_token_file(token_file_name)
    JSON.parse(token_as_get_object_output.body.read).deep_symbolize_keys!
  rescue => e
    raise TokenRetrievalError, "Token retrieval failed for user with ICN: #{current_user.icn}, Error: #{e.message}"
  end

  ##
  # Deletes token from S3 or locally
  #
  # @return [boolean]
  # @raise TokenDeletionError
  def delete_token(current_user, device_key)
    return delete_locally(current_user, device_key) if vsp_env_local || vsp_env_test

    delete_device_token_files(current_user, device_key)
    delete_icn_folder(current_user)
  rescue => e
    raise(TokenDeletionError, "Error deleting token in s3 for icn: #{current_user.icn}, error: #{e.message}")
  end

  private

  def delete_icn_folder(current_user)
    contents = get_s3_bucket_objects(s3_resource, "icn=#{current_user.icn}/")
    contents.batch_delete! if !contents.first.nil? && contents.all? { |item| item.size.zero? }
  rescue => e
    raise(TokenDeletionError, "Error deleting icn folder in s3 for icn: #{current_user.icn}, error: #{e.message}")
  end

  def delete_device_token_files(current_user, device_key)
    get_s3_bucket_objects(s3_resource, generate_prefix(current_user, device_key)).batch_delete!
  rescue => e
    raise(
      TokenDeletionError,
      "Error deleting files in s3 for icn: #{current_user.icn} device: #{device_key}, error: #{e.message}"
    )
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      region: Settings.dhp.s3.region,
      access_key_id: Settings.dhp.s3.aws_access_key_id,
      secret_access_key: Settings.dhp.s3.aws_secret_access_key
    )
  end

  def s3_resource
    @s3_resource ||= Aws::S3::Resource.new(client: s3_client)
  end

  def vsp_env_local
    Settings.vsp_environment == 'localhost'
  end

  def vsp_env_test
    Settings.vsp_environment == 'test'
  end

  def generate_prefix(current_user, device_key)
    "icn=#{current_user.icn}/device=#{device_key}/"
  end

  def get_s3_bucket_objects(s3_resource, prefix)
    s3_resource.bucket(Settings.dhp.s3.bucket).objects({ prefix: })
  end

  def token_file_path(prefix)
    Rails.root.join("modules/dhp_connected_devices/tmp/#{prefix}tokens.json").to_s
  end

  ##
  # Lists files in S3 bucket
  #
  # @return [Aws::S3::Types::ListObjectsV2Output]
  # @raise TokenRetrievalError
  def lists_files_in_bucket(prefix)
    resp = s3_client.list_objects_v2(
      { bucket: Settings.dhp.s3.bucket, prefix: }
    )
    resp.contents.empty? ? raise(TokenRetrievalError, "No files in #{prefix} or #{prefix} does not exist.") : resp
  end

  ##
  # Selects file ending in .json from list
  #
  # @return [Aws::S3::Types::Object]
  # @raise TokenRetrievalError
  def select_token_file(files)
    result = files.select { |o| o.key.ends_with?('.json') }.first
    result || raise(TokenRetrievalError, "Error finding file in S3 ending in .json: #{files}.")
  end

  ##
  # Retrieves token file from S3
  #
  # @return [Aws::S3::Types::Object]
  # @raise TokenRetrievalError
  def get_token_file(file_name)
    s3_client.get_object(bucket: Settings.dhp.s3.bucket, key: file_name)
  rescue => e
    raise(TokenRetrievalError, "Error fetching #{file_name}: #{e}")
  end

  ##
  # Package tokens to match Spark's token schema
  #
  # @return [json]
  # @raise TokenStorageError
  def unpack_payload(tokens_hash)
    unpacked_token = {
      payload: {
        access_token: tokens_hash[:access_token],
        refresh_token: tokens_hash[:refresh_token],
        scope: tokens_hash[:scope].gsub(' ', ','),
        expires_in: tokens_hash[:expires_in],
        received_at: Time.now.utc.strftime('%s%L')
      }
    }
    JSON.dump(unpacked_token)
  rescue => e
    raise TokenStorageError, "Error when unpacking token: #{tokens_hash}, #{e}"
  end

  ##
  # Stores tokens as a read-write file according to the Spark schema
  # @return [boolean]
  # @raise TokenStorageError
  def store_locally(current_user, device_key, payload_json)
    token_file_path = token_file_path(generate_prefix(current_user, device_key))

    begin
      dirname = File.dirname(token_file_path)
      FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
      File.write(token_file_path, payload_json)
      true
    rescue => e
      raise TokenStorageError, "Error with storing locally: #{payload_json}, #{e}"
    end
  end

  ##
  # Retrieves token json from local storage and converts it to a hash
  #
  # @return [Hash]
  # @raise TokenRetrievalError
  def get_locally(current_user, device_key)
    token_file_path = token_file_path(generate_prefix(current_user, device_key))
    begin
      token = File.read(token_file_path)
      JSON.parse(token).deep_symbolize_keys!
    rescue => e
      raise TokenRetrievalError, "Error retrieving token locally for icn: #{current_user.icn}, #{e}"
    end
  end

  ##
  # Deletes token from local storage
  #
  # @return [boolean]
  # @raise TokenDeletionError
  def delete_locally(current_user, device_key)
    token_file_path = token_file_path(generate_prefix(current_user, device_key))
    begin
      File.delete(token_file_path) == 1
    rescue => e
      raise TokenDeletionError, "Error deleting token locally for icn: #{current_user.icn}, #{e}"
    end
  end
end
