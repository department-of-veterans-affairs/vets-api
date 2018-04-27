# frozen_string_literal: true

module AwsHelpers
  def stub_reports_s3(filename)
    url = 'http://foo'

    s3 = double
    uuid = 'foo'
    bucket = double
    obj = double

    expect(Aws::S3::Resource).to receive(:new).once.with(
      region: 'region',
      access_key_id: 'key',
      secret_access_key: 'secret'
    ).and_return(s3)
    expect(SecureRandom).to receive(:uuid).once.and_return(uuid)
    expect(s3).to receive(:bucket).once.with('bucket').and_return(bucket)
    expect(bucket).to receive(:object).once.with("#{uuid}.csv").and_return(obj)
    expect(obj).to receive(:upload_file).once.with(filename, content_type: 'text/csv')
    expect(obj).to receive(:presigned_url).once.with(:get, expires_in: 1.week.to_i).and_return(url)

    yield

    url
  end
end
