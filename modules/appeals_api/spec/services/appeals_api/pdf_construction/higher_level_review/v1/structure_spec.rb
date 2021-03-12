# frozen_string_literal: true

require 'rails_helper'
require 'central_mail/datestamp_pdf'

module AppealsApi
  module PdfConstruction
    module HigherLevelReview
      module V1
        describe Structure do
          let(:higher_level_review) { create(:extra_higher_level_review) }

          describe '#form_fill' do
            it 'returns a Hash' do
              result = described_class.new(higher_level_review).form_fill

              expect(result.class).to eq(Hash)
            end
          end

          describe '#insert_overlaid_pages' do
            it 'does nothing' do
              form_fill_path = Prawn::Document.new.render_file("/tmp/#{higher_level_review.id}.pdf")
              result = described_class.new(higher_level_review).insert_overlaid_pages(form_fill_path)

              expect(result).to eq(form_fill_path)
            end
          end

          describe 'add_additional_pages' do
            it 'returns a Prawn::Document' do
              result = described_class.new(higher_level_review).add_additional_pages
              expect(result.class).to eq(Prawn::Document)
            end

            it 'has 1 page' do
              result = described_class.new(higher_level_review).add_additional_pages
              expect(result.page_count).to eq(1)
            end
          end

          describe 'stamp' do
            it 'returns the supplied pdf path' do
              allow(File).to receive(:delete)
              result = described_class.new(higher_level_review).stamp('dummy_path.pdf')
              expect(result[-4..]).to eq('.pdf')
            end
          end

          describe 'form_title' do
            it 'returns the HLR doc title' do
              expect(described_class.new(higher_level_review).form_title).to eq('200996')
            end
          end
        end
      end
    end
  end
end
