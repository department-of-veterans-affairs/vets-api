module PdfFill
  class ExtrasGenerator
    def initialize
      @text = ''
    end

    def add_text(text)
      @text += "#{text}\n"
    end

    def generate
      file_path = "tmp/pdfs/extras_#{Time.zone.now}.pdf"

      Prawn::Document.generate(file_path) do
        text(@text)
      end

      file_path
    end
  end
end
