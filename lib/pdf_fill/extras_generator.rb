module PdfFill
  class ExtrasGenerator
    def initialize
      @text = ''
    end

    def add_text(text)
      @text += "#{text}\n"
    end

    def generate
      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/extras_#{Time.zone.now}.pdf"
      the_text = @text

      Prawn::Document.generate(file_path) do
        text(the_text)
      end

      file_path
    end
  end
end
