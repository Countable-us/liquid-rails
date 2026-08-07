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

Liquid extensions belong to an application environment, not Liquid's global default environment. Configure render policy in an initializer:

```ruby
Liquid::Rails.configure do |config|
  config.render_errors = :raise
  config.cache_size = 1_000
  config.cache_namespace = ->(view) { view.liquid_registers[:site_id] }
end
```

The Liquid Rails Railtie owns the application-environment lifecycle. On every Rails prepare pass it builds a fresh strict environment, discovers the application's conventional extensions, and atomically installs the completed environment. Installing a replacement advances the environment generation, so subsequent renders parse against the current extension classes after a development reload. Applications should not add a second `to_prepare` callback for this work.

Do not use `Liquid::Template.register_filter`, `Liquid::Template.register_tag`, or mutate `Liquid::Environment.default`; 1.0 does not use global registration.

### Application extension discovery

Liquid Rails discovers application filters from `lib/liquid/filters` and tags from `lib/liquid/tags` by default. The directory names describe the extension type: place filters in the filters location and tags in the tags location.

Override either location with a relative or absolute path-like value. Set a location to `nil` to disable discovery for that extension type:

```ruby
Liquid::Rails.configure do |config|
  config.filters_location = Rails.root.join("lib/liquid/filters")
  config.tags_location = nil
end
```

### Manual environment construction

Manual construction is an alternative lifecycle, not an addition to the Railtie lifecycle. Use it only in a nonstandard host that does not run the Railtie-owned installation, disable automatic discovery, and make one host callback the sole environment owner:

```ruby
Liquid::Rails.configure do |config|
  config.filters_location = nil
  config.tags_location = nil
end

environment = Liquid::Rails.build_environment(error_mode: :strict) do |liquid|
  liquid.register_filter(MyApplicationFilter)
  liquid.register_tag("my_tag", MyApplicationTag)
end
Liquid::Rails.environment = environment
```

Run that construction from the single lifecycle hook chosen by the host. Ordinary Rails applications should use the Railtie-owned discovery lifecycle above.

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

`Liquid::Rails::Drop` copies its options and propagates them through declared associations. Association and collection items infer a conventional `ProductDrop` from a `Product` record even when `Product` does not include `Droppable`; use `class_name:` or `with:` only when the adapter does not follow that naming convention. Models still must include `Droppable` when their own `to_liquid` conversion should be available.

`Liquid::Rails::CollectionDrop` deliberately exposes a small Liquid surface: iteration, sliced loop loading, integer indexing, `first`, `last`, `count`, `size`/`length`, `empty?`, `total_count`, and `total_pages`, plus scopes declared with `.scope`. Pagination integrations can call its Ruby `page` and `per` methods before rendering. It does not dispatch arbitrary Ruby methods or expose its source collection to templates. Ruby integrations that need the underlying source may call `Liquid::Rails::CollectionDrop.unwrap(drop)`; it raises `ArgumentError` for anything other than a collection Drop.

## Generic extensions

The base environment registers generic Action View bridges for assets, URLs, translation, numbers, sanitization, dates, and text, together with `content_for`, `yield`, `csrf_meta_tags`, and `javascript_tag`. Application policy and vendor integrations—including tenant resources, navigation, and pagination—should be registered by the application environment.

## Testing

RSpec matchers are available to gem consumers:

```ruby
require "liquid-rails/matchers"
```
