# Creating custom RuboCop cops

## Basics

1. **Structure**: Cops inherit from `RuboCop::Cop::Base` and are organized in modules. Use the `RuboCop::Cop` namespace (at `lib/rubocop/cop/`).

2. **Pattern Matching**: Use `def_node_matcher` to define AST patterns that match code structures. The `parser` gem can help you understand the AST:
   ```bash
   ruby-parse -e 'your_code_here'
   ```

3. **Callbacks**: Implement callbacks like `on_send`, `on_class`, `on_def`, etc. to inspect specific node types.

4. **Adding Offenses**: Call `add_offense(node)` when a violation is detected.

5. **Autocorrect**: Extend `AutoCorrector` and use a corrector block with `add_offense`.

## Template

```ruby
module RuboCop
  module Cop
    class YourCopName < RuboCop::Cop::Base
      extend AutoCorrector  # if you want autocorrect

      MSG = 'Your message here'

      def_node_matcher :pattern_name?, <<~PATTERN
        # AST pattern here
      PATTERN

      def on_send(node)  # or on_class, on_def, etc.
        return unless pattern_name?(node)

        add_offense(node) do |corrector|
          # autocorrect logic
        end
      end
    end
  end
end
```

## Spec

```ruby
require 'rubocop_spec_helper'

# be sure to include `:config` 
RSpec.describe RuboCop::Cop::YourCopName, :config do
  it 'registers an offense when bad pattern is used' do
    expect_offense(<<~RUBY)
      bad_code_here
      ^^^^^^^^^^^^^ Your message here
    RUBY
  end

  it 'does not register an offense for good code' do
    expect_no_offenses(<<~RUBY)
      good_code_here
    RUBY
  end
end
```

*Note*: The caret count (`^`) must exactly match the length of the offending node.

## Setup usage

- Custom cops live in: `lib/rubocop/cop/`
- Load via `lib/rubocop/cop/.rubocop_custom_cops.yml`
- Enable via `Enabled: true` 

## Further reading

- https://docs.rubocop.org/rubocop/1.82/development.html
- https://docs.rubocop.org/rubocop-ast/
