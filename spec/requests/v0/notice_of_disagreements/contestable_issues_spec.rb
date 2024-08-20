# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe 'V0::NoticeOfDisagreements::ContestableIssues', type: :request do
  let(:user) { build(:user, :loa3) }

  before { sign_in_as(user) }

  describe '#index' do
    def personal_information_logs
      PersonalInformationLog.where 'error_class like ?',
                                   'V0::NoticeOfDisagreements::ContestableIssuesController#index exception % (NOD)'
    end

    subject { get '/v0/notice_of_disagreements/contestable_issues' }

    it 'fetches issues that the Veteran could contest via a notice of disagreement' do
      VCR.use_cassette('decision_review/NOD-GET-CONTESTABLE-ISSUES-RESPONSE-200') do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with({
                                                      message: 'Get contestable issues success!',
                                                      user_uuid: user.uuid,
                                                      action: 'Get contestable issues',
                                                      form_id: '10182',
                                                      upstream_system: 'Lighthouse',
                                                      downstream_system: nil,
                                                      is_success: true,
                                                      http: {
                                                        status_code: 200,
                                                        body: '[Redacted]'
                                                      }
                                                    })
        allow(StatsD).to receive(:increment)
        expect(StatsD).to receive(:increment).with('decision_review.form_10182.get_contestable_issues.success')
        subject
        expect(response).to be_successful
        expect(JSON.parse(response.body)['data']).to be_an Array
      end
    end

    it 'adds to the PersonalInformationLog when an exception is thrown' do
      VCR.use_cassette('decision_review/NOD-GET-CONTESTABLE-ISSUES-RESPONSE-404') do
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with({
                                                       message: 'Get contestable issues failure!',
                                                       user_uuid: user.uuid,
                                                       action: 'Get contestable issues',
                                                       form_id: '10182',
                                                       upstream_system: 'Lighthouse',
                                                       downstream_system: nil,
                                                       is_success: false,
                                                       http: {
                                                         status_code: 404,
                                                         body: anything
                                                       }
                                                     })
        allow(StatsD).to receive(:increment)
        expect(StatsD).to receive(:increment).with('decision_review.form_10182.get_contestable_issues.failure')
        expect(personal_information_logs.count).to be 0
        subject
        expect(personal_information_logs.count).to be 1
        pil = personal_information_logs.first
        expect(pil.data['user']).to be_truthy
        expect(pil.data['error']).to be_truthy
      end
    end
  end
end
