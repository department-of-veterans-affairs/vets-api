# frozen_string_literal: true

module HealthQuest
  module QuestionnaireManager
    module PdfGenerator
      ##
      # An object for generating PDFs from questionnaire response snapshots
      #
      # @!attribute opts
      #   @return [Hash]
      # @!attribute properties
      #   @return [HealthQuest::QuestionnaireManager::PdfGenerator::Properties]
      class Composer
        # This mixin allows you to create modular Prawn code without the
        # need to create subclasses of Prawn::Document.
        include Prawn::View
        include PdfGenerator

        attr_reader :opts, :properties

        ##
        # A method to create an instance of {HealthQuest::QuestionnaireManager::PdfGenerator::Composer}
        #
        # @param opts [Hash]
        # @return [HealthQuest::QuestionnaireManager::PdfGenerator::Composer]
        #
        def self.synthesize(opts = {})
          new(opts)
        end

        def initialize(opts)
          @opts = opts
          @properties = Properties.build

          build_pdf
        end

        def build_pdf
          stroke_axis
          set_font

          repeat(:all) do
            Header.build(opts: opts, composer: self).draw
            Footer.build(opts: opts, composer: self).draw
          end

          BasicAppointmentInfo.build(opts: opts, composer: self).draw
          bounding_box([0, bounds.top - 148], width: bounds.width, height: 670) do
            stroke_bounds
          end

          3.times { start_new_page }
        end

        ## Overriding #document allows you to set document options
        # or even use a custom document class
        # @see Properties#info
        # @return [Prawn::Document]
        #
        def document
          @document ||=
            Prawn::Document.new(
              page_size: properties.page_size,
              page_layout: properties.page_layout,
              margin: properties.margin,
              info: properties.info
            )
        end

        def set_font
          font_families.update(
            'HealthQuestPDF' => {
              normal: HealthQuest::Engine.root.join('lib', 'fonts', 'sourcesanspro-regular-webfont.ttf'),
              medium: HealthQuest::Engine.root.join('lib', 'fonts', 'sourcesanspro-bold-webfont.ttf'),
              bold: HealthQuest::Engine.root.join('lib', 'fonts', 'bitter-bold.ttf')
            }
          )
          font 'HealthQuestPDF'
        end
      end
    end
  end
end
