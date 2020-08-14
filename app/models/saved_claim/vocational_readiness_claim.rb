class SavedClaim::DisabilityCompensation < SavedClaim
FORM = '28-1900'

end
field_names = pdftk.get_field_names '/Users/kathleencrawford/code/vets-api/lib/pdf_fill/forms/pdfs/28-1900.pdf'

# ["VBA281900[0].#subform[0].DOBday[0]","VBA281900[0].#subform[0].VA_DATE_STAMP[0]"]

# [
  #<PdfForms::Field:0x00007f9f19a9e330 @type="Text",
  # @name="VBA281900[0].#subform[0].DOBday[0]",
  # @name_alt="4. Date of Birth. Enter 2 digit Day.",
  # @flags="25165824",
  # @value="",
  # @justification="Left",
  # @max_length="2">,
  # #<PdfForms::Field:0x00007f9f19a95230 @type="Text",
  # @name="VBA281900[0].#subform[0].VA_DATE_STAMP[0]",
  # @name_alt="VA DATE STAMP",
  # @flags="8392704",
  # @value="",
  # @justification="Center">
  # ]

def run_me
  pdftk = PdfForms.new('/usr/local/bin/pdftk')
  file_path = 'lib/pdf_fill/forms/pdfs/28-1900.pdf'
  temp_path = 'tmp/pdfs/28-1900_1.pdf'
  #new_hash = {'VBA281900[0].#subform[0].EmailAddress[0]'=> 'XYZ@GMAIL.COM'}
  new_hash = {}
  pdftk.fill_form(file_path, temp_path, new_hash, flatten: true)
end
