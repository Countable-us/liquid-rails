# Liquid Rails

Liquid Rails renders `.liquid` templates through Rails' Action View stack. Version 1.0 provides an application-scoped Liquid environment, explicit render policy, safe Drops, and a bounded parsed-template cache.

## Compatibility

Liquid Rails 1.0 supports Ruby `>= 3.3`, Rails `>= 8.0, < 8.2`, and Liquid `>= 5.13, < 6`.

## Installation

Add the gem to your application:

```ruby
gem "liquid-rails", "~> 1.0"
```

Then run `bundle install`. Rails registers `.liquid` as an Action View template handler, so layouts, partials, and regular templates can use the extension:

```liquid
{{ content_for_layout }}
{% include "shared/header" %}
```

## Configure rendering and extensions

Liquid extensions belong to an application environment, not Liquid's global default environment. Configure render policy and build a fresh environment during each Rails prepare pass:

```ruby
Liquid::Rails.configure do |config|
  config.render_errors = :raise
  config.cache_size = 1_000
  config.cache_namespace = ->(view) { view.liquid_registers[:site_id] }
end

Rails.application.config.to_prepare do
  environment = Liquid::Rails.build_environment(error_mode: :strict) do |liquid|
    liquid.register_filter(MyApplicationFilter)
    liquid.register_tag("my_tag", MyApplicationTag)
  end
  Liquid::Rails.environment = environment
end
```

`Liquid::Rails.build_environment` includes the supported generic Rails filters and tags. The block is the place to register application-specific filters and tags. Assigning `Liquid::Rails.environment` atomically installs the completed environment and advances its generation, so subsequent renders parse against the new extension set.

Do not use `Liquid::Template.register_filter`, `Liquid::Template.register_tag`, or mutate `Liquid::Environment.default`; 1.0 does not use global registration.

### Render inputs and errors

The handler builds fresh assigns and registers for every render. A view may provide application registers with `liquid_registers`:

```ruby
def liquid_registers
  { site_id: current_site.id.to_s, resources: Liquid::ResourceRegistry.new(site: current_site) }.freeze
end
```

The gem adds its own `:view`, `:controller`, `:helpers`, and `:file_system` registers. Those reserved names override colliding application-provided names. Treat assigns and registers as input: Liquid Rails does not mutate the caller's hashes.

`config.render_errors` accepts exactly two policies:

- `:raise` calls Liquid's raising renderer (`render!`) and propagates Liquid errors. This is the default.
- `:embed` calls Liquid's tolerant renderer (`render`) and returns Liquid's inline error output.

The setting is explicit; rendering behavior does not change automatically with `Rails.env`.

## Parsed-template caching

Caching is disabled until `cache_namespace` returns a value. A `nil` namespace bypasses the cache; `false` is still a valid namespace. The default cache holds 1,000 parsed-template prototypes globally across all namespaces, and `cache_size` must be a positive integer.

For tenant-aware applications, return an immutable tenant identifier such as `site_id`. A cache key contains the application namespace, installed environment generation, template identifier, virtual path, format, locale, and a SHA-256 digest of the complete source. This separates equal template paths and sources across tenants, invalidates entries after source changes, and re-parses after environment replacement.

Only a parsed prototype is cached. The handler duplicates its template wrapper for every render; it never caches rendered output, assigns, Drops, records, controllers, views, or register hashes. Custom tags must likewise be render-reentrant: parsed tag instances are shared through a cached prototype, so keep per-render state in local variables and Liquid context registers rather than tag instance variables.

## Drops and collections

Models opt in explicitly; Liquid Rails does not inject behavior into an ORM base class:

```ruby
class Product < ApplicationRecord
  include Liquid::Rails::Droppable
end

class ProductDrop < Liquid::Rails::Drop
  attributes :id, :name
  has_many :reviews
end
```

`Liquid::Rails::Drop` copies its options and propagates them through declared associations. Use explicit `Drop` classes for objects that should be exposed to templates.

`Liquid::Rails::CollectionDrop` deliberately exposes a small allowlist to Liquid: iteration, sliced loop loading, indexing, `first`, `last`, `count`, `size`/`length`, `empty?`, `page`, `per`, `total_count`, and `total_pages`, plus scopes declared with `.scope`. It does not dispatch arbitrary Ruby methods or expose its source collection to templates. Ruby integrations that need the underlying source may call `Liquid::Rails::CollectionDrop.unwrap(drop)`; it raises `ArgumentError` for anything other than a collection Drop.

## Generic extensions

The base environment registers generic Action View bridges for assets, URLs, translation, numbers, sanitization, dates, and text, together with `content_for`, `yield`, `csrf_meta_tags`, and `javascript_tag`. Application policy and vendor integrations—including tenant resources, navigation, and pagination—should be registered by the application environment.

## Testing

RSpec matchers are available to gem consumers:

```ruby
require "liquid-rails/matchers"
```
