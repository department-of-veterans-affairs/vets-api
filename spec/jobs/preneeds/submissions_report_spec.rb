# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::SubmissionsReport, type: :job do
  subject do
    described_class.new
  end

  before do
    error_class = 'PreneedsBurial'
    Settings.reports.token = 'asdf'
    Settings.reports.server = 'stage-tms.govdelivery.com'
    2.times do
      create(:personal_information_log, created_at: '2018-05-27')
      create(:personal_information_log,
             error_class: error_class,
             data: { response_body: '<returnCode>0</returnCode>' },
             created_at: '2018-05-26')
      create(:personal_information_log,
             error_class: error_class,
             data: { response_body: '<html>503 Service Unavailable</html>' },
             created_at: '2018-05-25')
    end
    create(:personal_information_log,
           error_class: error_class,
           data: { response_body: '<errorDescription>Error persisting PreNeedApplication</errorDescription>' },
           created_at: '2018-05-26')
    create(:personal_information_log,
           error_class: error_class,
           data: { response_body: '<returnCode>1111</returnCode>' },
           created_at: '2018-05-26')
  end

  describe '#perform', run_at: '2018-05-30 18:18:56' do
    it 'should query PersonalInformationLog for info' do
      expect(PreneedsSubmissionsReportMailer).to receive(:build).with(
        start_date: '2018-05-23',
        end_date: '2018-05-29',
        successes_count: 2,
        error_persisting_count: 1,
        server_unavailable_count: 2,
        other_errors_count: 1
      ).and_call_original
      expect_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now)
      subject.perform
    end
  end
end
