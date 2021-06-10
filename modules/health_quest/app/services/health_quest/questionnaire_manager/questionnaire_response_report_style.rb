# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    ##
    # An object for generating styles for the QuestionnaireResponseReport
    #
    class QuestionnaireResponseReportStyle
      def header_style
        {
          column_widths: { 1 => 460 },
          cell_style: {
            border_width: 0,
            size: 9,
            align: :right,
            padding: [0, 0, 10, 0]
          },
          header: true
        }
      end

      def default_table_style
        {
          column_widths: { 1 => 410 },
          cell_style: {
            border_width: 0,
            size: 12,
            align: :left,
            padding: [10, 10, 0, 0]
          },
          header: true
        }
      end

      def title_style
        {
          cell_style: {
            border_width: 0,
            size: 20,
            align: :left,
            font_style: :bold,
            padding: [0, 0, 0, 0]
          },
          header: true
        }
      end

      def table_question_style
        {
          column_widths: { 0 => 460 },
          cell_style: {
            border_width: 0,
            size: 12,
            align: :left,
            font_style: :bold,
            padding: [0, 0, 0, 20]
          },
          header: true
        }
      end

      def table_answer_style
        {
          cell_style: {
            border_width: 0,
            size: 12,
            align: :left,
            padding: [0, 0, 0, 20]
          },
          header: true
        }
      end

      def heading_one_style
        {
          cell_style: {
            border_width: 0,
            size: 16,
            align: :left,
            font_style: :bold,
            padding: 0
          },
          header: true
        }
      end

      def normal_text_style
        {
          cell_style: {
            border_width: 0,
            size: 12,
            align: :left,
            padding: [10, 10, 0, 0]
          },
          header: true
        }
      end

      def bold_text_style
        {
          cell_style: {
            border_width: 0,
            size: 12,
            align: :left,
            font_style: :bold,
            padding: [10, 10, 0, 0]
          },
          header: true
        }
      end

      def bold_text
        {
          style: :bold
        }
      end

      def logo_style
        {
          scale: 0.25,
          padding: 0
        }
      end
    end
  end
end
