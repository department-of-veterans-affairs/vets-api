# frozen_string_literal: true

require 'digest'
require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

class ExampleController < ApplicationController
  include AppealsApi::PdfDownloads
end

describe AppealsApi::PdfDownloads do
  include FixtureHelpers

  describe '#watermark' do
    let(:input_pdf_path) { fixture_filepath('higher_level_reviews/v0/pdfs/v3/expected_200996.pdf') }
    let!(:output_pdf_path) { described_class.watermark(input_pdf_path, 'output.pdf') }

    after do
      # FIXME: Test this in a more robust way
      # The watermark's text is diagonal, and the `match_pdf` matcher we have is not able to correctly detect it
      # (it instead appears jumbled with the rest of the form's text). For now, watermark code needs to be validated
      # manually by commenting this out and looking at the generated file in the rails tmp folder:
      FileUtils.rm_f(output_pdf_path)
    end

    it 'generates a version of the PDF with text unchanged and the watermark on each page' do
      expect(output_pdf_path).not_to match_pdf(input_pdf_path)
    end
  end

  describe ExampleController do
    let(:appeal) { create(:higher_level_review_v0) }
    let(:header_icn) { appeal.auth_headers['X-VA-ICN'] }
    let(:request_headers) { {} }

    before { request_headers.each { |k, v| request.headers[k] = v } }

    describe '#download_authorized?' do
      context 'when request has no X-VA-ICN header' do
        it 'is false' do
          expect(subject.download_authorized?(appeal)).to eq(false)
        end
      end

      context 'when request has X-VA-ICN header' do
        let(:request_headers) { { 'X-VA-ICN' => header_icn } }

        context "when the request's X-VA-ICN header matches the X-VA-ICN in the appeal's auth_headers" do
          it 'is true' do
            expect(subject.download_authorized?(appeal)).to eq(true)
          end
        end

        context 'when the original appeal has no saved X-VA-ICN in auth_headers but does have a veteran_icn value' do
          context 'when the ICNs match' do
            before do
              appeal.auth_headers.delete('X-VA-ICN')
              appeal.update!(veteran_icn: header_icn)
            end

            it 'is true' do
              expect(subject.download_authorized?(appeal)).to eq(true)
            end
          end

          context "when the ICNs don't match" do
            before do
              appeal.auth_headers.delete('X-VA-ICN')
              appeal.update!(veteran_icn: '0000000000V000000')
            end

            it 'is false' do
              expect(subject.download_authorized?(appeal)).to eq(false)
            end
          end
        end

        context 'when the original appeal has no saved ICN information and MPI profile must be looked up' do
          let(:cassette_name) { 'mpi/find_candidate/valid_icn_full' }

          before do
            appeal.auth_headers.delete('X-VA-ICN')
            VCR.insert_cassette(cassette_name)
          end

          after { VCR.eject_cassette(cassette_name) }

          context "X-VA-SSN from the appeal's auth_headers doesn't match the MPI profile retrieved for the ICN" do
            it 'is false' do
              expect(subject.download_authorized?(appeal)).to eq(false)
            end
          end

          context "when the appeal's X-VA-SSN header matches the MPI profile retrieved for the ICN" do
            before do
              appeal.auth_headers['X-VA-SSN'] = '796122306'
              appeal.save
            end

            it 'is true' do
              expect(subject.download_authorized?(appeal)).to eq(true)
            end
          end
        end

        context "when the appeal's auth_headers include only an X-VA-File-Number and no SSN or ICN" do
          let(:file_number) { '796122306' }

          before do
            appeal.auth_headers.delete('X-VA-SSN')
            appeal.auth_headers.delete('X-VA-ICN')
            appeal.auth_headers['X-VA-File-Number'] = file_number
            appeal.save
          end

          context 'when the user includes a matching X-VA-File-Number in their request' do
            let(:request_headers) do
              { 'X-VA-ICN' => header_icn, 'X-VA-File-Number' => file_number }
            end

            it 'is true' do
              expect(subject.download_authorized?(appeal)).to eq(true)
            end
          end

          context 'when the user includes a mismatched X-VA-File-Number in their request' do
            let(:request_headers) do
              { 'X-VA-ICN' => header_icn, 'X-VA-File-Number' => 'incorrect' }
            end

            it 'is false' do
              expect(subject.download_authorized?(appeal)).to eq(false)
            end
          end

          context 'when the user does not include an X-VA-File-Number in their request' do
            let(:request_headers) { { 'X-VA-ICN' => header_icn } }

            it 'is false' do
              expect(subject.download_authorized?(appeal)).to eq(false)
            end
          end
        end
      end
    end
  end
end
