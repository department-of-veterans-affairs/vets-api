# frozen_string_literal: true

shared_examples 'GET endpoint with optional Veteran ICN parameter' do |opts|
  let(:path) { opts[:path] || generated_path } # set :generated_path instead of opts[:path] if `let` context is needed
  let(:scope_base) { opts[:scope_base] }
  let(:headers) { opts[:headers].presence || {} }
  let(:mpi_cassette) { 'mpi/find_candidate/valid' }
  let(:cassettes) { (opts[:cassette] ? [opts[:cassette]] : []) + [mpi_cassette] }
  let(:default_params) { opts[:params].presence || {} }
  let(:params) { default_params }
  let(:icn) { '1012667145V762142' }

  before do
    cassettes.each { |cassette_name| VCR.insert_cassette(cassette_name) }
    with_openid_auth([scope]) { |auth_header| get(path, params:, headers: auth_header.merge(headers)) }
  end

  after { cassettes.each { |cassette_name| VCR.eject_cassette(cassette_name) } }

  describe 'successes' do
    context 'with veteran scope' do
      let(:scope) { "veteran/#{scope_base}.read" }

      context 'without ICN parameter' do
        it 'succeeds' do
          expect(response).to have_http_status(:ok)
        end
      end

      context 'with correct, optional ICN parameter' do
        let(:params) { default_params.merge({ icn: }) }

        it 'returns appeals' do
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with representative scope' do
      let(:scope) { "representative/#{scope_base}.read" }
      let(:params) { default_params.merge({ icn: }) }

      it 'returns appeals' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with system scope' do
      let(:scope) { "system/#{scope_base}.read" }
      let(:params) { default_params.merge({ icn: }) }

      it 'returns appeals' do
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'errors' do
    let(:error) { JSON.parse(response.body).dig('errors', 0) }
    let(:scope) { "veteran/#{scope_base}.read" }
    let(:params) { default_params.merge({ icn: }) }

    describe 'with veteran scope and incorrect optional ICN parameter' do
      let(:params) { default_params.merge({ icn: '1234567890V123456' }) }

      it 'returns a 403 error' do
        expect(response).to have_http_status(:forbidden)
        expect(error['detail']).to include('Veterans may access only their own records')
      end
    end

    describe 'with representative scope and missing required ICN parameter' do
      let(:scope) { "representative/#{scope_base}.read" }
      let(:params) { default_params }

      it 'returns a 400 error' do
        expect(response).to have_http_status(:bad_request)
        expect(error['detail']).to include("'icn' parameter is required")
      end
    end

    describe 'with system scope and missing required ICN parameter' do
      let(:scope) { "system/#{scope_base}.read" }
      let(:params) { default_params }

      it 'returns a 400 error' do
        expect(response).to have_http_status(:bad_request)
        expect(error['detail']).to include("'icn' parameter is required")
      end
    end

    unless opts[:skip_ssn_lookup_tests]
      describe 'MPI SSN lookup errors' do
        describe 'when veteran SSN is not found in MPI based on the provided ICN' do
          let(:mpi_cassette) { 'mpi/find_candidate/icn_not_found' }

          it 'returns a 404 error with a message that does not reference SSN' do
            expect(response).to have_http_status(:not_found)
            expect(error['detail']).not_to include('SSN')
          end
        end

        describe 'when MPI throws an error' do
          let(:mpi_cassette) { 'mpi/find_candidate/internal_server_error' }

          it 'returns a 502 error instead' do
            expect(response).to have_http_status(:bad_gateway)
          end
        end
      end
    end
  end
end
