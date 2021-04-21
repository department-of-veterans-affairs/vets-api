# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::QuestionnaireResponseReportStyle do
  subject { described_class.new }

  describe '#header_style' do
    it 'has a header_style' do
      hash = {
        column_widths: { 1 => 460 },
        cell_style: {
          border_width: 0,
          size: 9,
          align: :right,
          padding: [0, 0, 10, 0]
        }
      }

      expect(subject.header_style).to eq(hash)
    end
  end

  describe '#default_table_style' do
    it 'has a default_table_style' do
      hash = {
        column_widths: { 1 => 410 },
        cell_style: {
          border_width: 0,
          size: 11,
          align: :left,
          padding: [10, 10, 0, 0]
        }
      }

      expect(subject.default_table_style).to eq(hash)
    end
  end

  describe '#title_style' do
    it 'has a title_style' do
      hash = {
        cell_style: {
          border_width: 0,
          size: 16,
          align: :left,
          font_style: :bold,
          padding: [0, 0, 0, 0]
        }
      }

      expect(subject.title_style).to eq(hash)
    end
  end

  describe '#table_question_style' do
    it 'has a table_question_style' do
      hash = {
        column_widths: { 0 => 460 },
        cell_style: {
          border_width: 0,
          size: 12,
          align: :left,
          font_style: :bold,
          padding: [0, 0, 0, 20]
        }
      }

      expect(subject.table_question_style).to eq(hash)
    end
  end

  describe '#table_answer_style' do
    it 'has a table_answer_style' do
      hash = {
        cell_style: {
          border_width: 0,
          size: 12,
          align: :left,
          padding: [0, 0, 0, 20]
        }
      }

      expect(subject.table_answer_style).to eq(hash)
    end
  end

  describe '#heading_one_style' do
    it 'has a heading_one_style' do
      hash = {
        cell_style: {
          border_width: 0,
          size: 14,
          align: :left,
          font_style: :bold,
          padding: [24, 0, 0, 0]
        }
      }

      expect(subject.heading_one_style).to eq(hash)
    end
  end

  describe '#heading_two_style' do
    it 'has a heading_two_style' do
      hash = {
        cell_style: {
          border_width: 0,
          size: 14,
          align: :left,
          font_style: :bold,
          padding: [0, 0, 0, 0]
        }
      }

      expect(subject.heading_two_style).to eq(hash)
    end
  end

  describe '#normal_text_style' do
    it 'has a normal_text_style' do
      hash = {
        cell_style: {
          border_width: 0,
          size: 12,
          align: :left,
          padding: [10, 10, 0, 0]
        }
      }

      expect(subject.normal_text_style).to eq(hash)
    end
  end

  describe '#bold_text' do
    it 'has a bold_text' do
      hash = {
        style: :bold
      }

      expect(subject.bold_text).to eq(hash)
    end
  end

  describe '#logo_style' do
    it 'has a logo_style' do
      hash = {
        scale: 0.25,
        padding: 0
      }

      expect(subject.logo_style).to eq(hash)
    end
  end
end
