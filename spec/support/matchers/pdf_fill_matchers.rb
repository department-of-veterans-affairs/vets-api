RSpec::Matchers.define :match_pdf_fields do
  match(notify_expectation_failures: true) do |actual|
    fields = [actual, expected].map do |path|
      debugger
      PdfForms.new(Settings.binaries.pdftk).get_fields(path).map do |field|
        { name: field.name, value: field.value }
      end
    end
    expect(fields[0]).to eq(fields[1])
  end

  failure_message do |actual|
    "expected that #{actual} would match PDF fields of #{expected}"
  end
end

RSpec::Matchers.define :match_file_exactly do
  match do |actual|
    expect(FileUtils.compare_file(actual, expected)).to be(true)
  end

  failure_message do |actual|
    "expected that #{actual} would match #{expected} exactly"
  end
end