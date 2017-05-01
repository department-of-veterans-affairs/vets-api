# Upload Worklows

Upload Workflows are built around 3 concepts:

 * 'Uploaders', which are based on the `Shrine` gem.
 * 'Workflows', which chain together a series of small, asynchronous steps
 * 'Tasks', which are those small steps. This could be converting file formats, or sending it to an external service.

These concepts are bound together by the `FileUpload` class, which is where we define which uploader and workflow to use for a given file.

```
class Test::Upload < FileUpload
  uploader Test::Uploader
  workflow Test::Workflow
end
```

When instantiated, an instance of `Test::Upload` will be able take a file and any relevant extra metadata and run through the upload and storage process defined in `Test::Uploader`, and then begin the asynchronous `Test::Workflow`. For instance, if we use the following instance, both `user_uuid` and `tracked_item_id` will be available to Shrine and the `Tasks` in the `Workflow`.

```ruby
uploader = Test::Upload.new(user_uuid: SecureRandom.hex, tracked_item_id: rand(100))
```

To actually start the process, we pass in an IO object and optional trace_id, to the `start!` method:

```ruby
uploader.start!(File.open('README.md'), trace: request.uuid)
```

The file will be moved into Shrine's cache storage, and the `trace` will be added to the Workflow data. When any of the Tasks are run, the `trace` will be printed in the logs allowing us to follow a file from the user-initiated upload through all of the Tasks.


```
# frozen_string_literal: true
class Test::Uploader < Shrine
  plugin :validation_helpers

  def generate_location(_, context)
    record = context[:record]
    File.join(*[record.user_uuid.to_s, record.tracked_item_id.to_s, super].compact)
  end

  Attacher.validate do
    # validate_min_size 1024
    validate_max_size 10.megabytes
  end
end
```

Because `Uploaders` are subclasses of Shrine we can use any plugins or method overrides, including doing things like overriding storage locations to include data like the `user_uuid` and `tracked_item_id` that were passed in during the Uploader's creation.

```
# frozen_string_literal: true
class Test::Workflow < Workflow::File
  run Workflow::Task::ConvertToPDF
  run Workflow::Task::StampPDF, at: [10, 20], text: 'Test Approved'
  run Workflow::Task::MoveToLTS, destroy: true
end
```

While some arguments like `user_uuid` are going to be different per-invocation, some are applicable just to the instance of a Task in a given workflow. For instance, we may want the Stamp text to change between workflows, and that's possible by assinging them here in the Workflow definition.

```
class Workflow::Task::StampPDF < Workflow::Task::ShrineFile::Base
  def run(settings)
    f = file.download # Get a local working copy
    stamp = "#{settings[:text]} @ #{Time.current} for #{data['user_uuid']} by vets.gov"
    stamped_file = PDFLibrary.stamp(f, x: settings[:at][:x], y: settings[:at][:y], text: stamp)
    update_file(io: stamped_file)
    data[:stamped_at] = stamp
  end
end
```

Those Task-specific settings are passed in as an argument to the task, while the `user_uuid` arguments are in a `data` accessor that jobs can also update with additional data for other jobs to make use of. Additionally, the ShrineFile::Base class provides a way to add new versions of a file while retaining the old versions until all processing is complete.


