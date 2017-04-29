# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EVSS::FailedClaimsReport, type: :job do
  describe '#perform' do
    it 'should lookup claims on s3 and send the email' do
      s3 = double
      bucket = double
      objects = [double, double]

      objects.each_with_index do |object, i|
        last_modified = (i.zero? ? 5 : 45).days.ago
        allow(object).to receive(:last_modified).and_return(last_modified)
        allow(object).to receive(:key).and_return("object#{i}")
      end

      expect(Aws::S3::Resource).to receive(:new).once.with(
        region: 'evss_s3_region'
      ).and_return(s3)
      allow(s3).to receive(:bucket).twice.and_return(bucket)
      allow(bucket).to receive(:objects).and_return(objects)

      expect(FailedClaimsReportMailer).to receive(:build).once.with(
        %w(object1 object1)
      ).and_return(double.tap do |mailer|
        expect(mailer).to receive(:deliver_now).once
      end)

      subject.perform
    end
  end
end
