class SavedClaim::DisabilityCompensation < SavedClaim
FORM = '28-1900'

end
field_names = pdftk.get_field_names '/Users/derekdyer/Documents/vets-api/lib/pdf_fill/forms/pdfs/VBA-28-1900-ARE.pdf'

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