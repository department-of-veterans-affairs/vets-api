# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreements::EvidenceSubmissionsController, type: :request do
  include FixtureHelpers
  let(:notice_of_disagreement) { create(:notice_of_disagreement_v0, :board_review_hearing) }
  let(:headers) do
    headers = fixture_as_json 'notice_of_disagreements/v0/valid_10182_headers.json'
    # Temporary until this endpoint can be refactored to expect file number in the body instead of headers
    headers['X-VA-File-Number'] = notice_of_disagreement.veteran.file_number
    headers
  end
  let(:evidence_submissions) { create_list(:evidence_submission, 3, supportable: notice_of_disagreement) }
  let(:path) { '/services/appeals/notice-of-disagreements/v0/evidence-submissions' }
  let(:parsed) { JSON.parse(response.body) }

  def stub_upload_location(expected_location = 'http://some.fakesite.com/path/uuid')
    allow_any_instance_of(VBADocuments::UploadSubmission).to receive(:get_location).and_return(expected_location)
  end

  describe '#create' do
    let(:params) { { nod_uuid: notice_of_disagreement.id } }

    before do
      stub_upload_location
      notice_of_disagreement.update(board_review_option: 'evidence_submission')
    end

    it_behaves_like(
      'an endpoint with OpenID auth',
      scopes: described_class::OAUTH_SCOPES[:POST],
      success_status: :accepted
    ) do
      def make_request(auth_header)
        post(path, params:, headers: headers.merge(auth_header))
      end
    end
  end

  describe '#show' do
    before { stub_upload_location }

    it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:GET]) do
      def make_request(auth_header)
        get("#{path}/#{evidence_submissions.sample.guid}", headers: auth_header)
      end
    end
  end
end
