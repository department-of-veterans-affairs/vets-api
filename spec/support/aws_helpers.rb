# frozen_string_literal: true

module AwsHelpers
  # def stub_reports_s3(filename)
  #   url = 'http://foo'

  #   s3 = double
  #   uuid = 'foo'
  #   bucket = double
  #   obj = double

  #   expect(Aws::S3::Resource).to receive(:new).once.with(
  #     region: 'region',
  #     access_key_id: 'key',
  #     secret_access_key: 'secret'
  #   ).and_return(s3)
  #   expect(SecureRandom).to receive(:uuid).once.and_return(uuid)
  #   expect(s3).to receive(:bucket).once.with('bucket').and_return(bucket)
  #   expect(bucket).to receive(:object).once.with("#{uuid}.csv").and_return(obj)
  #   expect(obj).to receive(:upload_file).once.with(filename, content_type: 'text/csv')
  #   expect(obj).to receive(:presigned_url).once.with(:get, expires_in: 1.week.to_i).and_return(url)

  #   yield

  #   url
  # end

  def stub_reports_s3
    s3_client = double('s3_client')
    s3_object = double('s3_object')
    s3_bucket = double('s3_bucket')
    s3_resource = double('s3_resource')

    # Stub the chain: s3_resource.bucket(bucket_name).object(key)
    allow(s3_resource).to receive(:client).and_return(s3_client)
    allow(s3_resource).to receive(:bucket).and_return(s3_bucket)
    allow(s3_bucket).to receive(:object).and_return(s3_object)

    # Stub the presigned_url method with expires_in parameter
    allow(s3_object).to receive(:presigned_url)
      .with(:get, expires_in: 604800)
      .and_return('https://s3.amazonaws.com/bucket/test-file.pdf?presigned=true')

    allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)

    # Stub the TransferManager upload
    transfer_manager = double('transfer_manager')
    allow(Aws::S3::TransferManager).to receive(:new)
      .with(client: s3_client)
      .and_return(transfer_manager)

    allow(transfer_manager).to receive(:upload_file).and_return(true)
  end

  def stub_maintenance_windows_s3(filename)
    s3 = double
    bucket = double
    obj = double

    expect(Aws::S3::Resource).to receive(:new).once.with(
      region: 'region',
      access_key_id: 'key',
      secret_access_key: 'secret'
    ).and_return(s3)
    expect(s3).to receive(:bucket).once.with('bucket').and_return(bucket)
    expect(bucket).to receive(:object).once.with('maintenance_windows.json').and_return(obj)
    expect(obj).to receive(:upload_file).once.with(filename, acl: 'public-read', content_type: 'application/json')
  end
end
