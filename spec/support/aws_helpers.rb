# frozen_string_literal: true

require 'common/s3_helpers'

module AwsHelpers
  # Stub S3 uploads for report generation tests.
  # Since we now use Common::S3Helpers, we stub at that level for cleaner tests.
  def stub_reports_s3
    s3_object = instance_double(Aws::S3::Object)
    s3_resource = instance_double(Aws::S3::Resource)

    # Stub S3 resource creation
    allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)

    # Stub the Common::S3Helpers.upload_file to return an S3 object
    allow(Common::S3Helpers).to receive(:upload_file).and_return(s3_object)

    # Stub presigned_url method on the returned object
    allow(s3_object).to receive(:presigned_url)
      .with(:get, expires_in: 604_800)
      .and_return('https://s3.amazonaws.com/bucket/test-file.pdf?presigned=true')

    yield
  end

  # Stub S3 uploads for maintenance windows uploader tests.
  def stub_maintenance_windows_s3(_filename)
    s3_resource = instance_double(Aws::S3::Resource)

    # Stub S3 resource creation
    allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)

    # Stub the Common::S3Helpers.upload_file
    allow(Common::S3Helpers).to receive(:upload_file).and_return(true)
  end
end
