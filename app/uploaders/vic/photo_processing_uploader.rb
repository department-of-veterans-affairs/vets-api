module VIC
  class PhotoProcessingUploader < ProcessingUploader
    def initialize(*args)
      super

      if Rails.env.production?
        self.aws_acl = 'public-read'
      end
    end
  end
end
