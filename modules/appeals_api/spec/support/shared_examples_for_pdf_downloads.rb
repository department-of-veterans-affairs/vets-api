# frozen_string_literal: true

shared_examples 'watermarked pdf download endpoint' do |opts|
  let(:created_at) { Time.current }
  let(:status) { 'pending' }
  let(:appeal) { create(opts[:factory], created_at:, status:) }
  let(:uuid) { appeal.id }
  let(:api_segment) { appeal.class.name.demodulize.underscore.dasherize }
  let(:form_number) { described_class::FORM_NUMBER }
  let(:path) { "/services/appeals/#{api_segment}s/v0/forms/#{form_number}/#{uuid}/download" }
  let(:pdf_version) { opts[:pdf_version] || 'v3' }
  let(:veteran_icn) { '0000000000V000000' }
  let(:headers) { { 'X-VA-ICN' => veteran_icn } }
  let(:download_authorized) { true }
  let(:i18n_args) { { type: appeal.class.name.demodulize, id: appeal.id } }
  let(:expunged_attrs) do
    # opts[:expunged_attrs] should be any model attributes required to qualify an appeal record for the PII expunge job
    { status: 'complete' }.merge(opts[:expunged_attrs] || {})
  end

  before do
    # See AppealsApi::PdfDownloads specs for tests of `download_authorized?`
    allow_any_instance_of(AppealsApi::PdfDownloads)
      .to receive(:download_authorized?).and_return(download_authorized)

    with_openid_auth(described_class::OAUTH_SCOPES[:GET]) do |auth_header|
      get(path, headers: headers.merge(auth_header))
    end
  end

  context 'without X-VA-ICN header' do
    let(:headers) { {} }

    it 'returns a 422 error' do
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('X-VA-ICN is required')
    end
  end

  context 'when appeal is not found' do
    let(:uuid) { '11111111-1111-1111-1111-111111111111' }

    it 'returns a 404 error' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when appeal has error status' do
    let(:status) { 'error' }

    it 'returns a 422 error' do
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t('appeals_api.errors.pdf_download_in_error', **i18n_args))
    end
  end

  context 'when unauthorized' do
    let(:download_authorized) { false }

    it 'returns a 404 error' do
      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('not found')
    end
  end

  context 'when appeal is not yet submitted' do
    it 'returns a 422 error' do
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t('appeals_api.errors.pdf_download_not_ready', **i18n_args))
    end
  end

  context 'when PII has been expunged after the expiration period' do
    let(:appeal_attrs) { { pdf_version:, **expunged_attrs } }
    let(:appeal) do
      Timecop.freeze(1.year.ago) { create(opts[:factory], **appeal_attrs) }
    end

    context 'when the current X-VA-ICN header does not match the veteran_icn recorded on the appeal' do
      let(:appeal_attrs) { { pdf_version:, **expunged_attrs, veteran_icn: 'no-match' } }

      it 'returns a 404 error' do
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include('not found')
      end
    end

    context 'when the current X-VA-ICN header matches the veteran_icn recorded on the appeal' do
      let(:appeal_attrs) { { pdf_version:, **expunged_attrs, veteran_icn: } }

      it 'returns a 410 error' do
        expect(response).to have_http_status(:gone)
        expect(response.body).to include(I18n.t('appeals_api.errors.pdf_download_expired', **i18n_args))
      end
    end

    context 'when the appeal has neither auth_headers nor recorded veteran_icn' do
      let(:appeal_attrs) { { pdf_version:, **expunged_attrs } }

      it 'returns a 410 error' do
        expect(response).to have_http_status(:gone)
        expect(response.body).to include(I18n.t('appeals_api.errors.pdf_download_expired', **i18n_args))
      end
    end
  end

  context 'when appeal is submitted' do
    let(:appeal) { create(opts[:factory], created_at:, pdf_version:, status: 'submitted') }
    let(:expected_filename) { "#{form_number}-#{api_segment}-#{uuid}.pdf" }

    after { FileUtils.rm_f(expected_filename) }

    it 'returns a PDF' do
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/pdf; charset=utf-8')
      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.headers['Content-Disposition']).to include("filename=\"#{expected_filename}\"")
    end
  end
end
