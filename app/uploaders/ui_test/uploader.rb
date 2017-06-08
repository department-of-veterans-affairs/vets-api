class UITest::Uploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 1.megabytes
    validate_mime_type_inclusion %w(image/jpeg application/pdf text/plain application/octet-stream)
  end
end
