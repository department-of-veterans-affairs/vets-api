module PdfFill
  class ExtrasGenerator
    def initialize
      @text = ''
    end

    def add_text(text)
      @text += "#{text}\n"
    end

    def generate
      Prawn::Document.generate("hello.pdf") do
        text "Hello World!"
      end
    end
  end
end
