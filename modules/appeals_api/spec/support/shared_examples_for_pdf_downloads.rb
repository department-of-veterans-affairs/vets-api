# frozen_string_literal: true

# rubocop:disable RSpec/VariableName, Layout/LineLength
shared_examples 'watermarked pdf download endpoint' do |opts|
  let(:created_at) { Time.current }
  let(:status) { 'pending' }
  let!(:appeal) { create(opts[:factory], created_at:, status:) }
  let(:uuid) { appeal.id }
  let(:other_uuid) { '11111111-1111-1111-1111-111111111111' }
  let(:api_segment) { appeal.class.name.demodulize.underscore.dasherize }
  let(:form_number) { described_class::FORM_NUMBER }
  let(:path) do
    if opts[:decision_reviews]
      "/services/appeals/v2/decision_reviews/#{api_segment.underscore}s/#{uuid}/download"
    else
      "/services/appeals/#{api_segment}s/v0/forms/#{form_number}/#{uuid}/download"
    end
  end
  let(:pdf_version) { opts[:pdf_version] || 'v3' }
  let(:veteran_icn) { appeal.veteran.icn }
  let(:other_icn) { '1111111111V111111' }
  let(:params) { opts[:decision_reviews] ? {} : { icn: veteran_icn } }
  let(:headers) { opts[:decision_reviews] ? { 'X-VA-ICN' => veteran_icn } : {} }
  let(:i18n_args) { { type: appeal.class.name.demodulize, id: appeal.id } }
  let(:expunged_attrs) do
    # opts[:expunged_attrs] should be any model attributes required to qualify an appeal record for the PII expunge job
    { status: 'complete' }.merge(opts[:expunged_attrs] || {})
  end

  before do
    scopes = defined?(described_class::OAUTH_SCOPES) ? described_class::OAUTH_SCOPES[:GET] : []

    with_openid_auth(scopes) do |auth_header|
      get(path, headers: headers.merge(auth_header), params:)
    end
  end

  context 'without icn parameter/header' do
    let(:params) { {} }
    let(:headers) { {} }

    it 'returns a 422 error' do
      expect(response).to have_http_status(:unprocessable_entity)
      if opts[:decision_reviews]
        expect(response.body).to include('X-VA-ICN is required')
      else
        expect(response.body).to include("'icn' parameter is required")
      end
    end
  end

  context 'when appeal is not found' do
    let(:uuid) { other_uuid }

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

  context 'when the provided ICN parameter does not match the veteran_icn on the appeal' do
    let(:params) { opts[:decision_reviews] ? {} : { icn: other_icn } }
    let(:headers) { opts[:decision_reviews] ? { 'X-VA-ICN' => other_icn } : {} }

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

    context 'when the provided ICN parameter does not match the veteran_icn recorded on the appeal' do
      let(:params) { opts[:decision_reviews] ? {} : { icn: other_icn } }
      let(:headers) { opts[:decision_reviews] ? { 'X-VA-ICN' => other_icn } : {} }

      it 'returns a 404 error' do
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include('not found')
      end
    end

    context 'when the provided ICN parameter matches the veteran_icn recorded on the appeal' do
      it 'returns a 410 error' do
        expect(response).to have_http_status(:gone)
        expect(response.body).to include(I18n.t('appeals_api.errors.pdf_download_expired', **i18n_args))
      end
    end

    context 'when the appeal has neither PII nor a recorded veteran_icn' do
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

shared_examples 'PDF download docs' do |opts|
  example_id = '44444444-5555-6666-7777-888888888888'
  example_icn = '0123456789V012345'

  description <<~DESC
    Returns a watermarked copy of a #{opts[:appeal_type_display_name]} PDF as submitted to the VA. PDFs are available
    with the following caveats:

    1. The PDF download will become available only after after the #{opts[:appeal_type_display_name]} has progressed to
       the 'submitted' state.
    2. The PDF will stop being available one week after the #{opts[:appeal_type_display_name]} has progressed to the
       'completed' state. This is when the Veteran's personally identifying information is purged from our servers.
  DESC

  consumes 'application/json'

  let!(:appeal) do
    record = FactoryBot.create(
      opts[:factory],
      id: example_id,
      pdf_version: 'v3',
      status: 'submitted',
      veteran_icn: example_icn
    )

    record.form_data['data']['attributes']['veteran']['icn'] = example_icn
    record.save
    record
  end

  parameter(
    parameter_from_schema('shared/v0/icn.json', 'properties', 'icn').merge(
      {
        description: "ICN of the Veteran associated with the #{opts[:appeal_type_display_name]}",
        example: example_icn,
        in: :query,
        required: true
      }
    )
  )

  let(:icn) { example_icn }

  parameter name: :id,
            in: :path,
            description: "#{opts[:appeal_type_display_name]} ID",
            schema: { type: :string, format: :uuid },
            example: example_id

  let(:id) { example_id }

  response '200', 'Success' do
    produces 'application/pdf'

    after do |example|
      Dir.glob("*-#{id}.pdf").each { |f| FileUtils.rm_f(f) }

      example.metadata[:response][:content] = {
        'application/pdf' => { schema: { type: :file } }
      }
    end

    # rubocop:disable RSpec/NoExpectationExample
    it 'returns a PDF of the appeal submission' do
      # No-op: response is not JSON, don't let rswag try to parse it
    end
    # rubocop:enable RSpec/NoExpectationExample
  end

  response '404', "#{opts[:appeal_type_display_name]} record was not found, or the provided 'icn' query parameter does not match the record's ICN" do
    schema '$ref' => '#/components/schemas/errorModel'
    produces 'application/json'

    let(:icn) { '0000000000V000000' }

    it_behaves_like 'rswag example', desc: 'Not found', scopes: opts[:scopes]
  end

  response '410', 'Personally identifying information gone' do
    schema '$ref' => '#/components/schemas/errorModel'
    produces 'application/json'

    let(:appeal) do
      record = FactoryBot.create(
        opts[:factory],
        id: example_id,
        pdf_version: 'v3',
        status: 'submitted',
        veteran_icn: example_icn
      )

      record.update!(form_data: nil, auth_headers: nil, auth_headers_ciphertext: nil, form_data_ciphertext: nil)
      record
    end

    it_behaves_like 'rswag example',
                    desc: "Data for the #{opts[:appeal_type_display_name]} has been deleted from the server because the retention period for the veteran's personally identifying information has expired",
                    scopes: opts[:scopes]
  end

  response '422', 'Unable to return a PDF' do
    schema '$ref' => '#/components/schemas/errorModel'
    produces 'application/json'

    before { appeal.update!(status: 'pending') }

    it_behaves_like 'rswag example',
                    desc: "#{opts[:appeal_type_display_name]} has not yet progressed to a 'submitted' state",
                    scopes: opts[:scopes]
  end

  response '422', "Missing 'icn' query parameter" do
    schema '$ref' => '#/components/schemas/errorModel'
    produces 'application/json'

    let(:icn) {}

    it_behaves_like 'rswag example', desc: "Missing 'icn' parameter", scopes: opts[:scopes]
  end

  it_behaves_like 'rswag 500 response'
end

shared_examples 'decision reviews PDF download docs' do |opts|
  example_uuid = '44444444-5555-6666-7777-888888888888'
  example_icn = '0123456789V012345'

  description <<~DESC
    Returns a watermarked copy of a #{opts[:appeal_type_display_name]} PDF as submitted to the VA. PDFs are available
    with the following caveats:

    1. The PDF download will become available only after after the #{opts[:appeal_type_display_name]} has progressed to
       the 'submitted' state.
    2. The PDF will stop being available one week after the #{opts[:appeal_type_display_name]} has progressed to the
       'completed' state. This is when the Veteran's personally identifying information is purged from our servers.
    3. PDFs are only available for #{opts[:appeal_type_display_name]}s created with an associated Veteran ICN, which is
       provided in the `X-VA-ICN` header when the appeal is first created. If the appeal was not created with an
       `X-VA-ICN` header, a PDF will never become available.
  DESC

  consumes 'application/json'

  let!(:appeal) do
    record = FactoryBot.create(
      opts[:factory],
      id: example_uuid,
      pdf_version: 'v3',
      status: 'submitted',
      veteran_icn: example_icn
    )

    record.auth_headers['X-VA-ICN'] = example_icn
    record.save
    record
  end

  parameter AppealsApi::SwaggerSharedComponents.header_params[:veteran_icn_header].merge(
    description: "ICN of the Veteran associated with the #{opts[:appeal_type_display_name]}",
    example: example_icn
  )

  let(:'X-VA-ICN') { example_icn }

  parameter name: :uuid,
            in: :path,
            type: :string,
            description: "#{opts[:appeal_type_display_name]} UUID",
            example: example_uuid

  let(:uuid) { example_uuid }

  response '200', 'Success' do
    produces 'application/pdf'

    after do |example|
      Dir.glob("*-#{uuid}.pdf").each { |f| FileUtils.rm_f(f) }

      example.metadata[:response][:content] = {
        'application/pdf' => { schema: { type: :file } }
      }
    end

    # rubocop:disable RSpec/NoExpectationExample
    it 'returns a PDF of the appeal submission' do
      # No-op: response is not JSON, don't let rswag try to parse it
    end
    # rubocop:enable RSpec/NoExpectationExample
  end

  response '404', "#{opts[:appeal_type_display_name]} record was not found, or the provided X-VA-ICN header does not match the record's ICN, or the record was not created with an ICN" do
    schema '$ref' => '#/components/schemas/errorModel'
    produces 'application/json'

    let(:'X-VA-ICN') { '0000000000V000000' }

    it_behaves_like 'rswag example', desc: 'Not found'
  end

  response '410', 'Personally identifying information gone' do
    schema '$ref' => '#/components/schemas/errorModel'
    produces 'application/json'

    let(:appeal) do
      record = FactoryBot.create(
        opts[:factory],
        id: example_uuid,
        pdf_version: 'v3',
        status: 'submitted',
        veteran_icn: example_icn
      )

      record.update!(form_data: nil, auth_headers: nil, auth_headers_ciphertext: nil, form_data_ciphertext: nil)
      record
    end

    it_behaves_like 'rswag example',
                    desc: "Data for the #{opts[:appeal_type_display_name]} has been deleted from the server because the retention period for the veteran's personally identifying information has expired"
  end

  response '422', 'Unable to return a PDF' do
    schema '$ref' => '#/components/schemas/errorModel'
    produces 'application/json'

    before { appeal.update!(status: 'pending') }

    it_behaves_like 'rswag example',
                    desc: "#{opts[:appeal_type_display_name]} has not yet progressed to a 'submitted' state"
  end

  response '422', 'Missing X-VA-ICN header' do
    schema '$ref' => '#/components/schemas/errorModel'
    produces 'application/json'

    let(:'X-VA-ICN') {}

    it_behaves_like 'rswag example', desc: 'Missing X-VA-ICN header'
  end

  it_behaves_like 'rswag 500 response'
end
# rubocop:enable RSpec/VariableName, Layout/LineLength
