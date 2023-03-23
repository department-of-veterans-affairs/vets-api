# frozen_string_literal: true

module SetAWSConfig
  def set_aws_config(aws_access_key_id, aws_secret_access_key, region, bucket)
    self.aws_credentials = {
      access_key_id: aws_access_key_id,
      secret_access_key: aws_secret_access_key,
      region:
    }
    self.aws_acl = 'private'
    self.aws_bucket = bucket
    self.aws_attributes = { server_side_encryption: 'AES256' }
    self.class.storage = :aws
  end
end
