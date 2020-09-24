# frozen_string_literal: true

module SpecTempFiles
  def temp(name, contents, args = {})
    f = Tempfile.new(name, **args)
    f.write(contents)
    f.flush
    f
  end
end
