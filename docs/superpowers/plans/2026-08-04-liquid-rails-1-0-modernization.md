# Liquid Rails 1.0 Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Release a modern Liquid Rails 1.0 core and migrate the `site/` consumer to site-owned navigation, pagination, tenant resources, and tenant-safe parsed-template caching.

**Architecture:** The gem owns one explicit `Liquid::Environment`, pure render-input construction, a bounded process-local parsed-template cache, safe Drops, and generic Action View bridges. The site builds and installs its own environment extension set, supplies `site_id` as the cache namespace, and owns every integration that touches Pagy, `active_link_to`, `Current`, or application records.

**Tech Stack:** Ruby 3.3–4.0, Rails 8.0–8.1, Liquid 5.13, RSpec 8, Minitest, Pagy 6.5, Standard Ruby, GitHub Actions

## Global Constraints

- Ruby support is `>= 3.3`.
- Rails support is `>= 8.0`, `< 8.2`.
- Liquid support is `>= 5.13`, `< 6`.
- The platform remains on Ruby 3.4, Rails 8.1, and Liquid 5.13.
- The gem must not depend on Kaminari, Pagy, `active_link_to`, platform models, `Current`, or `site_id` semantics.
- `active_link_to`, Pagy pagination, tenant asset lookup, and domain tags belong to `site/`.
- Parsed-template cache keys must include the application namespace, environment generation, template identity, format/locale metadata, and complete source digest.
- The cache defaults to 1,000 entries globally across all tenants; missing namespace means no caching.
- Cache only a parsed prototype and duplicate its wrapper for every render. Never cache rendered output, assigns, Drops, registers, views, controllers, or records.
- Parsed tag objects are immutable after parsing; render methods use locals and context registers instead of assigning per-render instance state.
- Site resource memoization lasts for one render/request and is keyed by immutable `site_id` plus resource identity.
- `Action`, `Page`, and `Reaction` explicitly include `Liquid::Rails::Droppable`; no ORM base class is modified.
- Caller assigns and registers are immutable inputs. Site rendering always uses the `:raise` error policy.
- Preserve the platform repository's existing two local commits and all unrelated user changes.

## File Responsibility Map

### Liquid Rails gem

- `lib/liquid-rails/configuration.rb`: validates render policy and cache settings.
- `lib/liquid-rails/environment.rb`: builds the gem environment and owns the installed environment generation.
- `lib/liquid-rails/template_cache.rb`: thread-safe, globally bounded LRU storage for parsed prototypes.
- `lib/liquid-rails/template_handler.rb`: constructs fresh render inputs, selects error policy, and uses the cache.
- `lib/liquid-rails/file_system.rb`: resolves partials through public Action View lookup APIs.
- `lib/liquid-rails/drops/drop.rb`: immutable Drop options and association propagation.
- `lib/liquid-rails/drops/collection_drop.rb`: explicit lazy collection contract and Ruby-only unwrap API.
- `lib/liquid-rails/filters/*.rb` and `lib/liquid-rails/tags/*.rb`: generic Rails bridges without registration side effects.
- `lib/liquid-rails.rb`: explicit loading and public configuration/environment API.
- `liquid-rails.gemspec`, `Gemfile`, `gemfiles/`, `.github/workflows/ci.yml`: supported dependency contract and verification matrix.

### Site application

- `site/config/initializers/liquid.rb`: builds and atomically installs the site environment.
- `site/lib/liquid/filters/navigation.rb`: Liquid adapter for `active_link_to`.
- `site/lib/liquid/tags/paginate.rb`: first-class Pagy tag.
- `site/app/services/liquid/resource_registry.rb`: per-render, tenant-bound resource lookup and memoization.
- `site/app/controllers/application_controller.rb`: supplies `liquid_registers` to views.
- `site/lib/liquid/filters/asset_url.rb`: registry-backed asset lookup.
- `site/lib/liquid/tags/render_action.rb`, `render_campaign.rb`: registry-backed nested rendering.
- `site/app/drops/actions_drop.rb`, `campaigns_drop.rb`: registry-backed scoped lookup.
- `site/app/models/action.rb`, `page.rb`, `reaction.rb`: explicit Droppable opt-in.

---

### Task 1: Establish the 1.0 dependency and CI baseline

**Repository:** `/Users/sean/code/countable/liquid-rails`

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `gemfiles/rails_80.gemfile`
- Create: `gemfiles/rails_81.gemfile`
- Create: `spec/lib/liquid-rails/gemspec_spec.rb`
- Modify: `.ruby-version`
- Modify: `Gemfile`
- Modify: `Rakefile`
- Modify: `liquid-rails.gemspec`
- Modify: `lib/liquid-rails/version.rb`
- Modify: `spec/dummy/config/application.rb`
- Modify: `spec/dummy/config/boot.rb`
- Modify: `spec/dummy/config/environments/test.rb`
- Modify: `spec/spec_helper.rb`
- Delete: `.travis.yml`
- Delete: `.coveralls.yml`
- Delete: `.ruby-gemset`
- Delete: `Guardfile`
- Delete: `gemfiles/rails_50.gemfile`
- Delete: `gemfiles/rails_51.gemfile`
- Delete: `gemfiles/rails_52.gemfile`
- Delete: `gemfiles/rails_60.gemfile`
- Delete: `gemfiles/rails_61.gemfile`
- Delete: `spec/dummy/config/spring.rb`
- Delete: `spec/dummy/db/test.sqlite3`

**Interfaces:**
- Consumes: the approved support matrix from the design specification.
- Produces: gem version `1.0.0`, runtime dependency ranges, Rails 8 appraisal Gemfiles, and CI commands used by every later task.

- [ ] **Step 1: Add a failing gem metadata contract**

```ruby
# spec/lib/liquid-rails/gemspec_spec.rb
require "rubygems"
require_relative "../../../lib/liquid-rails/version"

RSpec.describe "liquid-rails.gemspec" do
  subject(:gemspec) do
    Gem::Specification.load(File.expand_path("../../../liquid-rails.gemspec", __dir__))
  end

  it "declares the 1.0 support contract" do
    expect(gemspec.version.to_s).to eq("1.0.0")
    expect(gemspec.required_ruby_version).to be_satisfied_by(Gem::Version.new("3.3.0"))
    expect(gemspec.required_ruby_version).not_to be_satisfied_by(Gem::Version.new("3.2.9"))

    dependencies = gemspec.runtime_dependencies.to_h { |dependency| [dependency.name, dependency.requirement.to_s] }
    expect(dependencies).to include("rails" => ">= 8.0, < 8.2", "liquid" => ">= 5.13, < 6")
    expect(dependencies).not_to have_key("kaminari")
  end
end
```

- [ ] **Step 2: Run the contract and confirm the old metadata fails**

Run: `bundle exec rspec spec/lib/liquid-rails/gemspec_spec.rb`

Expected: FAIL because the version is `0.2.3`, Ruby/Rails/Liquid floors are old, and Kaminari is present.

- [ ] **Step 3: Update gem and development dependency declarations**

Use these runtime declarations in `liquid-rails.gemspec`:

```ruby
spec.required_ruby_version = ">= 3.3"
spec.required_rubygems_version = ">= 3.5"

spec.add_dependency "rails", ">= 8.0", "< 8.2"
spec.add_dependency "liquid", ">= 5.13", "< 6"
```

Set `Liquid::Rails::VERSION = "1.0.0"`, set `.ruby-version` to the installed stable Ruby `3.4.5`, and reduce `Gemfile` to current development tools:

```ruby
source "https://rubygems.org"

gemspec

gem "capybara", "~> 3.40"
gem "rake", "~> 13.4"
gem "rspec-rails", "~> 8.0"
gem "sqlite3", "~> 2.9"
gem "standard", "~> 1.55", require: false
```

Make `rake` run RSpec, add `rake standard`, and make the default task depend on both.

- [ ] **Step 4: Replace obsolete appraisal files and CI**

Each Rails Gemfile must source the local gemspec, include its own test dependencies, and constrain one Rails line:

```ruby
# gemfiles/rails_80.gemfile
source "https://rubygems.org"
gemspec path: ".."
gem "rails", "~> 8.0.0"
gem "capybara", "~> 3.40"
gem "rake", "~> 13.4"
gem "rspec-rails", "~> 8.0"
gem "sqlite3", "~> 2.9"
gem "standard", "~> 1.55", require: false
```

```ruby
# gemfiles/rails_81.gemfile
source "https://rubygems.org"
gemspec path: ".."
gem "rails", "~> 8.1.0"
gem "capybara", "~> 3.40"
gem "rake", "~> 13.4"
gem "rspec-rails", "~> 8.0"
gem "sqlite3", "~> 2.9"
gem "standard", "~> 1.55", require: false
```

Use a GitHub Actions matrix with `ruby: [3.3, 3.4, 4.0]` and `gemfile: [rails_80, rails_81]`. Each job sets `BUNDLE_GEMFILE=gemfiles/${{ matrix.gemfile }}.gemfile`, installs dependencies, runs `bundle exec rspec`, runs `bundle exec standardrb`, and runs `gem build liquid-rails.gemspec`. Delete Travis configuration and all Rails 5/6 Gemfiles.

- [ ] **Step 5: Modernize the dummy application boot contract**

Set `config.load_defaults 8.0`, remove Rails 5 conditional configuration, change `config.cache_classes = true` to `config.enable_reloading = false`, set `config.action_dispatch.show_exceptions = :none`, and set a deterministic test `secret_key_base`. Remove Coveralls, SimpleCov, Guard, Spring, Pry, and the tracked SQLite test database. Correct `spec/dummy/config/boot.rb` to resolve the repository Gemfile and `lib/` directory three levels above `spec/dummy/config`:

```ruby
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../../Gemfile", __dir__)
require "bundler/setup"
$LOAD_PATH.unshift File.expand_path("../../../lib", __dir__)
```

- [ ] **Step 6: Install and verify metadata and dummy boot**

Run: `bundle install`

Run: `bundle exec rspec spec/lib/liquid-rails/gemspec_spec.rb`

Run: `bundle exec ruby spec/dummy/bin/rails runner -e test 'puts Rails.version'`

Expected: the spec passes and the runner prints a Rails 8 version without boot errors.

- [ ] **Step 7: Commit the dependency baseline**

```bash
git add -A .github .ruby-version .ruby-gemset .coveralls.yml Gemfile Gemfile.lock Guardfile Rakefile gemfiles liquid-rails.gemspec lib/liquid-rails/version.rb spec/dummy spec/spec_helper.rb spec/lib/liquid-rails/gemspec_spec.rb .travis.yml
git commit -m "build: establish Liquid Rails 1.0 support matrix"
```

### Task 2: Introduce an application-scoped Liquid environment

**Repository:** `/Users/sean/code/countable/liquid-rails`

**Files:**
- Create: `lib/liquid-rails/configuration.rb`
- Create: `lib/liquid-rails/environment.rb`
- Create: `spec/lib/liquid-rails/environment_spec.rb`
- Modify: `lib/liquid-rails.rb`
- Modify: `lib/liquid-rails/filters/asset_tag_filter.rb`
- Modify: `lib/liquid-rails/filters/asset_url_filter.rb`
- Modify: `lib/liquid-rails/filters/date_filter.rb`
- Modify: `lib/liquid-rails/filters/number_filter.rb`
- Modify: `lib/liquid-rails/filters/sanitize_filter.rb`
- Modify: `lib/liquid-rails/filters/text_filter.rb`
- Modify: `lib/liquid-rails/filters/translate_filter.rb`
- Modify: `lib/liquid-rails/filters/url_filter.rb`
- Modify: `lib/liquid-rails/tags/content_for_tag.rb`
- Modify: `lib/liquid-rails/tags/csrf_meta_tags.rb`
- Modify: `lib/liquid-rails/tags/javascript_tag.rb`
- Modify: `spec/spec_helper.rb`

**Interfaces:**
- Consumes: Liquid 5.13 `Liquid::Environment.build`, `register_filter`, and `register_tag`.
- Produces: `Liquid::Rails.configure`, `.configuration`, `.build_environment(error_mode:)`, `.environment`, `.environment=`, and `.environment_generation`.

- [ ] **Step 1: Write failing environment-isolation tests**

```ruby
# spec/lib/liquid-rails/environment_spec.rb
require "spec_helper"

RSpec.describe Liquid::Rails do
  module TestFilter
    def decorated(input)
      "[#{input}]"
    end
  end

  after do
    described_class.environment = described_class.build_environment(error_mode: :strict)
  end

  it "builds an isolated environment with gem defaults" do
    environment = described_class.build_environment(error_mode: :strict)
    environment.register_filter(TestFilter)

    expect(environment).not_to equal(Liquid::Environment.default)
    expect(Liquid::Template.parse("{{ 'value' | decorated }}", environment: environment).render).to eq("[value]")
    expect(Liquid::Template.parse("{{ 'value' | decorated }}", environment: Liquid::Environment.default).render).to eq("value")
    template = Liquid::Template.parse("{{ 1234 | number_with_delimiter }}", environment: environment)
    expect(template.render(registers: {view: helper})).to eq("1,234")
  end

  it "increments the generation when installing an environment" do
    generation = described_class.environment_generation
    described_class.environment = described_class.build_environment(error_mode: :strict)
    expect(described_class.environment_generation).to eq(generation + 1)
  end
end
```

Define `helper` with `ActionController::Base.helpers` in the spec.

- [ ] **Step 2: Run the tests and confirm the API is missing**

Run: `bundle exec rspec spec/lib/liquid-rails/environment_spec.rb`

Expected: FAIL because `build_environment`, configuration, and generation do not exist and the gem mutates the default environment while loading.

- [ ] **Step 3: Implement configuration validation**

```ruby
# lib/liquid-rails/configuration.rb
module Liquid
  module Rails
    class Configuration
      RENDER_ERROR_POLICIES = %i[raise embed].freeze

      attr_reader :cache_namespace, :cache_size, :render_errors

      def initialize
        @cache_namespace = nil
        @cache_size = 1_000
        @render_errors = :raise
      end

      def cache_size=(value)
        value = Integer(value)
        raise ArgumentError, "cache_size must be positive" unless value.positive?
        @cache_size = value
      end

      def cache_namespace=(value)
        raise ArgumentError, "cache_namespace must respond to call" if value && !value.respond_to?(:call)
        @cache_namespace = value
      end

      def render_errors=(value)
        value = value.to_sym
        raise ArgumentError, "render_errors must be :raise or :embed" unless RENDER_ERROR_POLICIES.include?(value)
        @render_errors = value
      end
    end
  end
end
```

- [ ] **Step 4: Build and install explicit environments**

`Liquid::Rails.build_environment(error_mode: :strict)` must call `Liquid::Environment.build`, register the retained filter modules and generic tags from frozen `DEFAULT_FILTERS` and `DEFAULT_TAGS` constants, yield the environment when a block is given, and return it. `environment=` must reject non-environment values, install atomically, and increment `@environment_generation`.

Use this public shape in `lib/liquid-rails.rb`:

```ruby
module Liquid
  module Rails
    class << self
      attr_reader :environment_generation

      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
        reset_template_cache! if respond_to?(:reset_template_cache!, true)
      end

      def environment
        return @environment if @environment
        self.environment = build_environment(error_mode: :strict)
      end

      def environment=(environment)
        raise ArgumentError, "expected Liquid::Environment" unless environment.is_a?(::Liquid::Environment)
        @environment = environment
        @environment_generation = environment_generation.to_i + 1
      end
    end
  end
end
```

- [ ] **Step 5: Make loading explicit and side-effect free**

Replace Ruby `autoload` and `Dir[...]` requires with explicit `require` statements in dependency order. Remove every trailing `Liquid::Rails.register_filter`, `register_tag`, and deprecated `Liquid::Template.register_*` call from retained filter and tag files. Remove the old compatibility registration methods from `Liquid::Rails`.

Update `spec/spec_helper.rb` to install a strict test environment:

```ruby
Liquid::Rails.environment = Liquid::Rails.build_environment(error_mode: :strict)
```

- [ ] **Step 6: Run environment and retained bridge tests**

Run: `bundle exec rspec spec/lib/liquid-rails/environment_spec.rb spec/lib/liquid-rails/filters spec/lib/liquid-rails/tags`

Expected: PASS without Liquid global-registration deprecations.

- [ ] **Step 7: Commit the scoped environment**

```bash
git add lib spec
git commit -m "feat: add scoped Liquid environment"
```

### Task 3: Add pure rendering and tenant-aware parsed-template caching

**Repository:** `/Users/sean/code/countable/liquid-rails`

**Files:**
- Create: `lib/liquid-rails/template_cache.rb`
- Create: `spec/lib/liquid-rails/template_cache_spec.rb`
- Modify: `lib/liquid-rails.rb`
- Modify: `lib/liquid-rails/template_handler.rb`
- Modify: `spec/lib/liquid-rails/template_handler_spec.rb`

**Interfaces:**
- Consumes: `Liquid::Rails.configuration`, `.environment`, and `.environment_generation` from Task 2.
- Produces: `TemplateCache#fetch(key)`, `Liquid::Rails.reset_template_cache!`, and `TemplateHandler#render(source, local_assigns = {}, metadata = {})`.

- [ ] **Step 1: Write failing bounded-cache tests**

```ruby
# spec/lib/liquid-rails/template_cache_spec.rb
require "spec_helper"

RSpec.describe Liquid::Rails::TemplateCache do
  it "returns a cached value and evicts the least recently used entry" do
    cache = described_class.new(max_size: 2)
    expect(cache.fetch(:one) { Object.new }).to equal(cache.fetch(:one) { Object.new })
    cache.fetch(:two) { :two }
    cache.fetch(:one) { :replacement }
    cache.fetch(:three) { :three }
    expect(cache.fetch(:two) { :reloaded }).to eq(:reloaded)
    expect(cache.size).to eq(2)
  end

  it "is safe under concurrent fetches" do
    cache = described_class.new(max_size: 10)
    threads = 20.times.map { |number| Thread.new { cache.fetch(number % 3) { number % 3 } } }
    expect(threads.map(&:value).sort.uniq).to eq([0, 1, 2])
    expect(cache.size).to eq(3)
  end
end
```

- [ ] **Step 2: Write failing handler contracts**

Add focused examples to `template_handler_spec.rb` that:

```ruby
it "does not mutate controller assigns or local assigns" do
  controller_assigns = {"title" => "Original"}
  local_assigns = {subtitle: "Local"}
  allow(controller).to receive(:liquid_assigns).and_return(controller_assigns)

  handler.render("{{ title }} {{ subtitle }}", local_assigns, identifier: "pages/show")

  expect(controller_assigns).to eq("title" => "Original")
  expect(local_assigns).to eq(subtitle: "Local")
end

it "separates equal template paths by namespace and source digest" do
  namespaces = ["site-1", "site-2", "site-1"]
  allow(Liquid::Rails.configuration).to receive(:cache_namespace) { ->(_view) { namespaces.shift } }
  allow(Liquid::Template).to receive(:parse).and_call_original

  expect(handler.render("one", {}, identifier: "pages/show")).to eq("one")
  expect(handler.render("two", {}, identifier: "pages/show")).to eq("two")
  expect(handler.render("changed", {}, identifier: "pages/show")).to eq("changed")
  expect(Liquid::Template).to have_received(:parse).exactly(3).times
end
```

Also cover: no namespace parses every time; a repeated full key parses once; replacing the environment parses again; `:raise` propagates `Liquid::Error`; `:embed` returns inline Liquid error output; nested renders reuse the same `:resources` object while receiving a fresh register hash; concurrent renders never exchange assigns or `site_id`.

- [ ] **Step 3: Run the focused tests and confirm failure**

Run: `bundle exec rspec spec/lib/liquid-rails/template_cache_spec.rb spec/lib/liquid-rails/template_handler_spec.rb`

Expected: FAIL because there is no bounded cache, rendering mutates assigns, parsing uses global `Liquid::Template`, and error policy depends on `Rails.env`.

- [ ] **Step 4: Implement the bounded cache**

```ruby
# lib/liquid-rails/template_cache.rb
module Liquid
  module Rails
    class TemplateCache
      attr_reader :max_size

      def initialize(max_size:)
        @max_size = Integer(max_size)
        @entries = {}
        @mutex = Mutex.new
      end

      def fetch(key)
        cached = @mutex.synchronize do
          next unless @entries.key?(key)
          value = @entries.delete(key)
          @entries[key] = value
        end
        return cached if cached

        value = yield
        @mutex.synchronize do
          @entries.delete(key)
          @entries[key] = value
          @entries.shift while @entries.size > max_size
        end
        value
      end

      def size
        @mutex.synchronize { @entries.size }
      end
    end
  end
end
```

Use an internal sentinel instead of `if cached` so a falsey cached value remains valid.

- [ ] **Step 5: Build fresh render inputs and cache keys**

In `TemplateHandler`, copy the selected controller/view assigns, stringify a copy of locals, and build registers as:

```ruby
def registers
  application_registers = if @view.respond_to?(:liquid_registers)
    @view.liquid_registers.to_h.dup
  else
    {}
  end

  application_registers.merge(
    view: @view,
    controller: @controller,
    helpers: @helper,
    file_system: Liquid::Rails::FileSystem.new(@view)
  )
end
```

The reserved keys in the final `merge` win. Build the cache key only when `configuration.cache_namespace.call(@view)` is non-nil:

```ruby
[
  namespace,
  Liquid::Rails.environment_generation,
  metadata[:identifier],
  metadata[:virtual_path],
  metadata[:format],
  metadata[:locale] || @view.lookup_context.locale,
  Digest::SHA256.hexdigest(source)
]
```

Parse with `Liquid::Template.parse(source, environment: Liquid::Rails.environment)`, cache the prototype, call `dup` before each render, and select `render!` for `:raise` or `render` for `:embed`. Remove `render_method` and every `Rails.env` branch.

Update `.call` to pass `identifier`, `virtual_path`, and `format` literals from the `ActionView::Template` into the generated handler call. Keep the metadata argument optional so site domain tags can render database strings.

- [ ] **Step 6: Run cache, handler, and feature rendering tests**

Run: `bundle exec rspec spec/lib/liquid-rails/template_cache_spec.rb spec/lib/liquid-rails/template_handler_spec.rb`

Run: `bundle exec rspec spec/lib/liquid-rails/template_handler_spec.rb`

Expected: PASS with no shared-state or deprecation warnings.

- [ ] **Step 7: Commit rendering and caching**

```bash
git add lib/liquid-rails.rb lib/liquid-rails/template_cache.rb lib/liquid-rails/template_handler.rb spec/lib/liquid-rails
git commit -m "feat: add tenant-aware Liquid template cache"
```

### Task 4: Make Drops immutable, lazy, and explicitly callable

**Repository:** `/Users/sean/code/countable/liquid-rails`

**Files:**
- Create: `spec/lib/liquid-rails/drops/collection_drop_spec.rb`
- Modify: `lib/liquid-rails/drops/drop.rb`
- Modify: `lib/liquid-rails/drops/collection_drop.rb`
- Modify: `lib/liquid-rails/drops/droppable.rb`
- Modify: `spec/lib/liquid-rails/drops/drop_spec.rb`
- Modify: `spec/fixtures/poro.rb`

**Interfaces:**
- Consumes: existing `Drop.dropify(resource, options = {})`, `attributes`, `belongs_to`, `has_many`, and `scope` declarations.
- Produces: immutable per-instance `options`, `current_user`, lazy `each`/`load_slice`, option-preserving `page`/`per`/scopes, and Ruby-only `CollectionDrop.unwrap(drop)`.

- [ ] **Step 1: Add failing option-isolation tests**

```ruby
it "does not mutate association declaration options across instances" do
  first = PostDrop.new(post, current_user: "first")
  second = PostDrop.new(post, current_user: "second")

  expect(first.comments.first.current_user).to eq("first")
  expect(second.comments.first.current_user).to eq("second")
  expect(PostDrop._associations[:comments][:options]).not_to have_key(:current_user)
end

it "preserves options through scopes and pagination" do
  collection = CommentsDrop.new(relation, current_user: "viewer", with: "CommentDrop")
  expect(collection.approved.first.current_user).to eq("viewer")
  expect(collection.page(2).per(5).first.current_user).to eq("viewer")
end
```

- [ ] **Step 2: Add failing collection allowlist and laziness tests**

```ruby
# spec/lib/liquid-rails/drops/collection_drop_spec.rb
RSpec.describe Liquid::Rails::CollectionDrop do
  it "supports Liquid iteration without eager mapping" do
    source = QuerySpy.new([Profile.new(name: "One"), Profile.new(name: "Two")])
    drop = described_class.new(source, with: "ProfileDrop", current_user: "viewer")

    rendered = Liquid::Template
      .parse("{% for item in items %}{{ item.name }}{% endfor %}", environment: Liquid::Rails.environment)
      .render!("items" => drop)

    expect(rendered).to eq("OneTwo")
    expect(source.each_calls).to eq(1)
  end

  it "does not dispatch arbitrary Ruby methods" do
    drop = described_class.new([Profile.new(name: "One")], with: "ProfileDrop")
    expect(drop["object_id"]).to be_nil
    expect(drop["to_json"]).to be_nil
  end

  it "exposes the source only through the Ruby class API" do
    source = [Profile.new(name: "One")]
    drop = described_class.new(source, with: "ProfileDrop")
    expect(described_class.unwrap(drop)).to equal(source)
    expect(drop["objects"]).to be_nil
  end
end
```

- [ ] **Step 3: Run Drop tests and confirm failure**

Run: `bundle exec rspec spec/lib/liquid-rails/drops/drop_spec.rb spec/lib/liquid-rails/drops/collection_drop_spec.rb`

Expected: FAIL at the existing missing `current_user`, shared association option mutation, eager mapping, and arbitrary `public_send` behavior.

- [ ] **Step 4: Copy Drop options and propagate them**

`Drop#initialize` must set `@object = object` and `@options = options.to_h.dup.freeze`. Add protected readers for both, plus:

```ruby
def current_user
  options[:current_user]
end
```

Freeze a distinct copy of association declaration options. Association access must call:

```ruby
association_options = options.merge(declaration_options)
Liquid::Rails::Drop.dropify(association, association_options)
```

Never write `current_user` into `declaration_options`.

- [ ] **Step 5: Replace broad Array delegation with a focused collection**

Implement public `each`, `load_slice`, `[]`, `first`, `last`, `count`, `size`, `length`, `empty?`, `page`, and `per`. Each returned item is wrapped through `drop_item(item, options)`. `scope`, `page`, and `per` construct the same collection class with the original copied options. String lookup in `[]` may invoke only names declared through `.scope`; every other string returns `nil`.

Keep limited Liquid loops lazy with this shape:

```ruby
def each
  return enum_for(__method__) unless block_given?
  objects.each { |item| yield drop_item(item, options) }
end

def load_slice(from, to)
  source = if objects.respond_to?(:offset) && objects.respond_to?(:limit)
    relation = objects.offset(from)
    to ? relation.limit(to - from) : relation
  else
    objects.slice(from...(to || objects.length)) || []
  end
  source.map { |item| drop_item(item, options) }
end
```

Implement the Ruby-only escape hatch as a class method:

```ruby
def self.unwrap(drop)
  raise ArgumentError, "expected CollectionDrop" unless drop.is_a?(CollectionDrop)
  drop.__send__(:objects)
end
```

Do not expose `objects`, `source`, `public_send`, arbitrary Array methods, or `Enumerable` methods to Liquid.

- [ ] **Step 6: Run all Drop and matcher specs**

Run: `bundle exec rspec spec/lib/liquid-rails/drops spec/lib/liquid-rails/rspec`

Expected: PASS, including the two-user isolation regression.

- [ ] **Step 7: Commit the Drop contract**

```bash
git add lib/liquid-rails/drops spec/lib/liquid-rails/drops spec/fixtures/poro.rb
git commit -m "fix: isolate Liquid drop state"
```

### Task 5: Complete the surgical gem cleanup and public Rails lookup migration

**Repository:** `/Users/sean/code/countable/liquid-rails`

**Files:**
- Create: `spec/lib/liquid-rails/file_system_spec.rb`
- Modify: `lib/liquid-rails/file_system.rb`
- Modify: `lib/liquid-rails/filters/text_filter.rb`
- Modify: `lib/liquid-rails/filters/url_filter.rb`
- Modify: `lib/liquid-rails/tags/content_for_tag.rb`
- Modify: `lib/liquid-rails/tags/csrf_meta_tags.rb`
- Modify: `lib/liquid-rails/railtie.rb`
- Modify: `lib/liquid-rails/matchers.rb`
- Modify: `lib/liquid-rails/rspec/drop_example_group.rb`
- Modify: `lib/liquid-rails/rspec/drop_matchers.rb`
- Modify: `lib/liquid-rails/rspec/filter_example_group.rb`
- Modify: `lib/liquid-rails/rspec/tag_example_group.rb`
- Modify: `lib/liquid-rails/rspec/view_controller_context.rb`
- Modify: `spec/lib/liquid-rails/filters/asset_tag_filter_spec.rb`
- Modify: `spec/lib/liquid-rails/filters/asset_url_filter_spec.rb`
- Modify: `spec/lib/liquid-rails/filters/date_filter_spec.rb`
- Modify: `spec/lib/liquid-rails/filters/number_filter_spec.rb`
- Modify: `spec/lib/liquid-rails/filters/sanitize_filter_spec.rb`
- Modify: `spec/lib/liquid-rails/filters/text_filter_spec.rb`
- Modify: `spec/lib/liquid-rails/filters/translate_filter_spec.rb`
- Modify: `spec/lib/liquid-rails/tags/content_for_tag_spec.rb`
- Modify: `spec/lib/liquid-rails/tags/csrf_meta_tag_spec.rb`
- Modify: `spec/lib/liquid-rails/rspec/drop_matchers_spec.rb`
- Delete: `lib/liquid-rails/filters/google_static_map_url_filter.rb`
- Delete: `lib/liquid-rails/filters/misc_filter.rb`
- Delete: `lib/liquid-rails/filters/paginate_filter.rb`
- Delete: `lib/liquid-rails/tags/google_analytics_tag.rb`
- Delete: `lib/liquid-rails/tags/javascript_pack_tag.rb`
- Delete: `lib/liquid-rails/tags/paginate_tag.rb`
- Delete: `lib/liquid-rails/tags/stylesheet_pack_tag.rb`
- Delete: their corresponding specs

**Interfaces:**
- Consumes: scoped environment default lists from Task 2.
- Produces: generic-only filter/tag surface, nil-safe generic tags, public Action View partial lookup, and a Railtie with no ORM injection.

- [ ] **Step 1: Add failing ownership and Railtie assertions**

```ruby
it "keeps URL helpers generic" do
  expect(Liquid::Rails::UrlFilter.instance_methods(false)).to contain_exactly(
    :current_page?, :link_to, :link_to_unless_current, :mail_to, :url_for
  )
end

it "does not inject Droppable into Active Record" do
  expect(ActiveRecord::Base.ancestors).not_to include(Liquid::Rails::Droppable)
end

it "returns an empty string when Rails has no CSRF or yielded content" do
  allow(view).to receive(:csrf_meta_tags).and_return(nil)
  allow(view).to receive(:content_for).and_return(nil)
  template = Liquid::Template.parse("{% csrf_meta_tags %}{% yield absent %}", environment: environment)
  expect(template.render!(registers: {view: view})).to eq("")
end
```

- [ ] **Step 2: Add a failing public lookup test**

```ruby
# spec/lib/liquid-rails/file_system_spec.rb
RSpec.describe Liquid::Rails::FileSystem do
  it "uses LookupContext#find_all with public arguments" do
    template = instance_double(ActionView::Template, source: "partial source")
    lookup_context = instance_double(ActionView::LookupContext)
    view = instance_double(ActionView::Base, controller_path: "pages", locale: :en, formats: [:html], lookup_context: lookup_context)
    allow(lookup_context).to receive(:find_all).with(
      "card", ["pages"], true, [],
      locale: [:en], formats: [:html], variants: [], handlers: [:liquid]
    ).and_return([template])

    expect(described_class.new(view).read_template_file("card")).to eq("partial source")
  end
end
```

- [ ] **Step 3: Run focused tests and confirm old behavior fails**

Run: `bundle exec rspec spec/lib/liquid-rails/file_system_spec.rb spec/lib/liquid-rails/railtie_spec.rb spec/lib/liquid-rails/tags spec/lib/liquid-rails/filters`

Expected: FAIL because `active_link_to` remains, ORM injection remains, nil values escape tags, and the filesystem calls resolver internals.

- [ ] **Step 4: Use the public lookup context**

Split a requested path into name and prefix, then call:

```ruby
templates = view.lookup_context.find_all(
  name,
  [prefix],
  true,
  [],
  locale: [view.locale],
  formats: view.formats,
  variants: [],
  handlers: [:liquid]
)
```

Raise `Liquid::FileSystemError` when empty and return the first source otherwise. Preserve controller-relative and fully qualified partial behavior through the existing feature specs.

- [ ] **Step 5: Remove site/vendor policy and dead APIs**

Delete the listed files and specs, remove them from environment default lists, remove `active_link_to` from `UrlFilter`, and remove `rjust`, `ljust`, `underscore`, `dasherize`, and custom `concat` from `TextFilter`. Keep only the Rails bridge methods approved in the design. Replace the legacy dummy-input URL signature with:

```ruby
def url_for(options)
  @context.registers.fetch(:view).url_for(options.to_h.deep_symbolize_keys)
end
```

Change both generic nil-prone tags to return strings and remove render-time assignment to `@context` so cached parsed tags remain immutable:

```ruby
context.registers[:view].csrf_meta_tags.to_s
context.registers[:view].content_for(@identifier).to_s.html_safe
```

Remove the Railtie initializer that loops over Active Record and Mongoid. Keep only template-handler registration and generator preference.

Simplify the optional RSpec support to current RSpec/Rails APIs: remove RSpec 2 and Rails 5 branches, build the test view through `ActionView::LookupContext`, and parse matcher examples through `Liquid::Rails.environment` rather than the global template environment. Keep the public matcher names `have_attribute`, `have_many`, `belongs_to`, and `have_scope`.

- [ ] **Step 6: Run the complete gem suite and Standard**

Run: `bundle exec rspec`

Run: `bundle exec standardrb --fix`

Run: `bundle exec rspec`

Expected: PASS with no Liquid Rails deprecation output.

- [ ] **Step 7: Commit the surgical cleanup**

```bash
git add -A lib spec
git commit -m "refactor: keep Liquid Rails integrations generic"
```

### Task 6: Migrate site-owned filters, tags, and explicit Drop opt-ins

**Repository:** `/Users/sean/code/csg/v2`

**Files:**
- Create: `site/lib/liquid/filters/navigation.rb`
- Create: `site/lib/liquid/tags/paginate.rb`
- Create: `site/test/lib/liquid/filters/navigation_test.rb`
- Create: `site/test/lib/liquid/tags/paginate_test.rb`
- Create: `site/test/integration/liquid_environment_test.rb`
- Modify: `site/Gemfile`
- Modify: `site/Gemfile.lock`
- Modify: `site/config/environments/test.rb`
- Modify: `site/config/initializers/liquid.rb`
- Modify: `site/lib/liquid/filters/asset_url.rb`
- Modify: `site/lib/liquid/filters/date.rb`
- Modify: `site/lib/liquid/filters/media.rb`
- Modify: `site/lib/liquid/filters/record.rb`
- Modify: `site/lib/liquid/filters/string.rb`
- Modify: `site/lib/liquid/tags/action_template.rb`
- Modify: `site/lib/liquid/tags/campaign_template.rb`
- Modify: `site/lib/liquid/tags/layout.rb`
- Modify: `site/lib/liquid/tags/render_action.rb`
- Modify: `site/lib/liquid/tags/render_campaign.rb`
- Modify: `site/lib/liquid/tags/schema.rb`
- Modify: `site/app/models/action.rb`
- Modify: `site/app/models/page.rb`
- Modify: `site/app/models/reaction.rb`
- Delete: `site/lib/liquid/rails/csrf_meta_tags.rb`
- Delete: `site/lib/liquid/rails/paginate_tag.rb`
- Delete: `site/lib/liquid/rails/yield_tag.rb`

**Interfaces:**
- Consumes: `Liquid::Rails.configure`, `.build_environment`, `.environment=`, nil-safe gem tags, and `CollectionDrop.unwrap`.
- Produces: site-owned `Liquid::Filters::Navigation`, `Liquid::Tags::Paginate`, explicit extension registration, and explicit model Droppable behavior.

- [ ] **Step 1: Point the site migration at Liquid Rails 1.0 for coordinated testing**

Change the Gemfile requirement to:

```ruby
gem "liquid-rails", "~> 1.0", github: "countable-us/liquid-rails", branch: "master"
```

During local execution, mount the gem repository at `/gems/liquid-rails` and configure Bundler's local git override; do not commit a developer-specific absolute path:

```bash
docker compose run --rm -v /Users/sean/code/countable/liquid-rails:/gems/liquid-rails site bundle config set --local local.liquid-rails /gems/liquid-rails
docker compose run --rm -v /Users/sean/code/countable/liquid-rails:/gems/liquid-rails site bundle update liquid-rails
```

- [ ] **Step 2: Add deterministic test-only encryption keys**

Add these inside the test environment configuration before `encrypt_fixtures`:

```ruby
config.active_record.encryption.primary_key = "liquid-rails-test-primary-key-2026"
config.active_record.encryption.deterministic_key = "liquid-rails-test-deterministic-key-2026"
config.active_record.encryption.key_derivation_salt = "liquid-rails-test-key-derivation-salt-2026"
config.active_record.encryption.encrypt_fixtures = true
```

These values exist only in `config/environments/test.rb`; no production fallback is added.

- [ ] **Step 3: Write failing environment and ownership tests**

```ruby
class LiquidEnvironmentTest < ActionDispatch::IntegrationTest
  test "installs site extensions without mutating Liquid's default environment" do
    assert_equal :strict, Liquid::Rails.environment.error_mode
    assert_equal :raise, Liquid::Rails.configuration.render_errors
    assert Liquid::Template.parse("{% paginate items by 1 %}{{ paginate.items }}{% endpaginate %}", environment: Liquid::Rails.environment)
    assert Liquid::Template.parse("{{ 'Home' | active_link_to: '/' }}", environment: Liquid::Rails.environment)
    refute Liquid::Environment.default.equal?(Liquid::Rails.environment)
  end

  test "only intended models opt into generated drops" do
    assert_instance_of ActionDrop, actions(:one).to_liquid
    assert_instance_of PageDrop, pages(:one).to_liquid
    assert_instance_of ReactionDrop, reactions(:advocacy_message).to_liquid
    refute User.new.respond_to?(:drop_class)
  end
end
```

Add navigation tests for string-to-symbol conversion of `active: "exclusive"`, `"inclusive"`, and `"exact"`, plus unchanged non-special values. Add pagination tests for integer and variable page sizes, invalid/non-positive sizes, arrays, CollectionDrops, and `PaginateDrop` output.

- [ ] **Step 4: Run the focused site tests and confirm migration failures**

Run from `/Users/sean/code/csg/v2`:

`docker compose run --rm -v /Users/sean/code/countable/liquid-rails:/gems/liquid-rails site bin/rails test test/integration/liquid_environment_test.rb test/lib/liquid/filters/navigation_test.rb test/lib/liquid/tags/paginate_test.rb`

Expected: FAIL because the site still globally registers extensions, monkey-patches gem tags, has no navigation filter class, and relies on ORM-wide Droppable injection.

- [ ] **Step 5: Implement the site navigation filter**

```ruby
module Liquid::Filters::Navigation
  ACTIVE_MODES = %w[exclusive inclusive exact].freeze

  def active_link_to(name, url, options = {})
    options = options.deep_symbolize_keys
    options[:active] = options[:active].to_sym if ACTIVE_MODES.include?(options[:active])
    @context.registers.fetch(:view).active_link_to(name, url.to_s, options)
  end
end
```

Remove `Liquid::Template.register_filter` from every site filter file.

- [ ] **Step 6: Replace the Pagy monkey patch with a normal tag**

Move the existing Pagy behavior into `Liquid::Tags::Paginate < Liquid::Block`. Parse integer or variable page-size expressions once during initialization. Resolve page size, collection, and Pagy values into local variables during each render; never overwrite parsed tag instance variables. Use `Liquid::Rails::CollectionDrop.unwrap(collection)` when needed, call `pagy_array` for Arrays and `pagy` for relations, assign `PaginateDrop.new(pagy, records)` to `context["paginate"]`, and render the block. Preserve `Pagy::DEFAULT[:items]` and the existing positive-integer error message.

Delete the three `class_eval` patch files. Remove every `Liquid::Template.register_tag` call from site tag files.

- [ ] **Step 7: Install site extensions atomically**

Use this initializer structure with an explicit frozen map of site tags and filters:

```ruby
Liquid::Rails.configure do |config|
  config.render_errors = :raise
  config.cache_size = 1_000
  config.cache_namespace = ->(view) { view.liquid_registers[:site_id] }
end

Rails.application.config.to_prepare do
  environment = Liquid::Rails.build_environment(error_mode: :strict) do |liquid|
    [
      Liquid::Filters::AssetUrl,
      Liquid::Filters::Date,
      Liquid::Filters::Media,
      Liquid::Filters::Navigation,
      Liquid::Filters::Record,
      Liquid::Filters::String
    ].each { |filter| liquid.register_filter(filter) }

    {
      "action_template" => Liquid::Tags::ActionTemplate,
      "campaign_template" => Liquid::Tags::CampaignTemplate,
      "layout" => Liquid::Tags::Layout,
      "paginate" => Liquid::Tags::Paginate,
      "render_action" => Liquid::Tags::RenderAction,
      "render_campaign" => Liquid::Tags::RenderCampaign,
      "schema" => Liquid::Tags::Schema
    }.each { |name, tag| liquid.register_tag(name, tag) }
  end

  Liquid::Rails.environment = environment
end
```

Do not use globbed `require`, `Liquid::Template.register_*`, or `Liquid::Environment.default`.

- [ ] **Step 8: Opt in only intended models and rerun tests**

Add `include Liquid::Rails::Droppable` to `Action`, `Page`, and `Reaction`. Run the three focused test files again.

Expected: PASS with no Liquid registration warnings and no encryption-key errors.

- [ ] **Step 9: Commit the site ownership migration**

```bash
git add site/Gemfile site/Gemfile.lock site/config site/lib/liquid site/app/models site/test/integration/liquid_environment_test.rb site/test/lib/liquid
git commit -m "refactor: move site Liquid extensions into application"
```

### Task 7: Add a per-render tenant resource registry and query ceilings

**Repository:** `/Users/sean/code/csg/v2`

**Files:**
- Create: `site/app/services/liquid/resource_registry.rb`
- Create: `site/test/services/liquid/resource_registry_test.rb`
- Create: `site/test/lib/liquid/filters/asset_url_test.rb`
- Modify: `site/app/controllers/application_controller.rb`
- Modify: `site/lib/liquid/filters/asset_url.rb`
- Modify: `site/lib/liquid/tags/render_action.rb`
- Modify: `site/lib/liquid/tags/render_campaign.rb`
- Modify: `site/app/drops/actions_drop.rb`
- Modify: `site/app/drops/campaigns_drop.rb`
- Create: `site/test/lib/liquid/tags/render_action_test.rb`
- Create: `site/test/lib/liquid/tags/render_campaign_test.rb`
- Create: `site/test/drops/resource_lookup_test.rb`

**Interfaces:**
- Consumes: the handler's `liquid_registers` hook and fresh-register merge from Task 3.
- Produces: `Liquid::ResourceRegistry.new(site:, actions: [], campaigns: [], assets: [])`, `#site_id`, `#action(slug, scope: nil)`, `#campaign(slug, scope: nil)`, and `#asset(name)`.

- [ ] **Step 1: Write failing tenant and memoization tests**

```ruby
class Liquid::ResourceRegistryTest < ActiveSupport::TestCase
  test "memoizes a site action without crossing sites" do
    first_site = sites(:site)
    second_site = sites(:basic)
    Current.site = first_site
    first_action = actions(:one)
    Current.site = second_site
    second_action = second_site.actions.create!(user: users(:one), slug: first_action.slug, name: "Other", template: "Other")
    Current.site = first_site

    registry = Liquid::ResourceRegistry.new(site: first_site)
    assert_queries(1) do
      assert_equal first_action, registry.action(first_action.slug)
      assert_equal first_action, registry.action(first_action.slug)
    end
    refute_equal second_action, registry.action(first_action.slug)
  end

  test "preloaded resources need no fallback query" do
    action = actions(:one)
    registry = Liquid::ResourceRegistry.new(site: sites(:site), actions: [action])
    assert_no_queries { assert_equal action, registry.action(action.slug) }
  end

  test "rejects a scope from another site" do
    other_site = sites(:basic)
    Current.site = other_site
    other_campaign = other_site.campaigns.create!(user: users(:one), slug: "other", name: "Other", template: "Other")
    Current.site = sites(:site)

    registry = Liquid::ResourceRegistry.new(site: sites(:site))
    assert_raises(ArgumentError) { registry.action("shared", scope: other_campaign) }
  end
end
```

Add this campaign contract in the same file, using the existing `campaigns(:one)` fixture:

```ruby
test "memoizes a campaign and uses a preload without queries" do
  campaign = campaigns(:one)
  registry = Liquid::ResourceRegistry.new(site: sites(:site))
  assert_queries(1) do
    assert_equal campaign, registry.campaign(campaign.slug)
    assert_equal campaign, registry.campaign(campaign.slug)
  end

  preloaded = Liquid::ResourceRegistry.new(site: sites(:site), campaigns: [campaign])
  assert_no_queries { assert_equal campaign, preloaded.campaign(campaign.slug) }
end
```

In `asset_url_test.rb`, create equal asset names under `sites(:site)` and `sites(:basic)`, build one registry for each, assert two calls for one name issue one ordered lookup, assert a preload issues none, and assert the returned records and generated URLs are different.

- [ ] **Step 2: Run registry and asset tests and confirm failure**

Run: `docker compose run --rm -v /Users/sean/code/countable/liquid-rails:/gems/liquid-rails site bin/rails test test/services/liquid/resource_registry_test.rb test/lib/liquid/filters/asset_url_test.rb`

Expected: FAIL because resource lookup is direct, the asset filter performs the same query twice per call, and there is no render registry.

- [ ] **Step 3: Implement tenant-bound resource lookup**

```ruby
class Liquid::ResourceRegistry
  attr_reader :site_id

  def initialize(site:, actions: [], campaigns: [], assets: [])
    @site = site
    @site_id = site&.id&.to_s&.freeze
    @actions = index(actions)
    @campaigns = index(campaigns)
    @assets = assets.group_by(&:name).transform_values { |records| records.max_by(&:created_at) }
  end

  def action(slug, scope: nil)
    fetch_scoped(@actions, slug, scope) { |relation| relation.actions.find_by(slug: slug.to_s) }
  end

  def campaign(slug, scope: nil)
    fetch_scoped(@campaigns, slug, scope) { |relation| relation.campaigns.find_by(slug: slug.to_s) }
  end

  def asset(name)
    key = name.to_s
    return @assets[key] if @assets.key?(key)
    @assets[key] = @site&.assets&.where(name: key)&.order(created_at: :desc)&.first
  end

  private

  def index(records)
    records.to_h { |record| [["Site", site_id, record.slug.to_s], record] }
  end

  def fetch_scoped(cache, slug, scope)
    ensure_same_site!(scope) if scope
    owner = scope || @site
    key = [owner.class.name, owner.id.to_s, slug.to_s]
    return cache[key] if cache.key?(key)
    cache[key] = yield(owner)
  end

  def ensure_same_site!(scope)
    raise ArgumentError, "resource scope belongs to another site" unless scope.site_id.to_s == site_id
  end
end
```

The `index` key exactly matches the site-level key built by `fetch_scoped`; preserve falsey memoization with `Hash#key?`.

- [ ] **Step 4: Supply one registry per request/render**

Expose a view helper in `ApplicationController`:

```ruby
helper_method :liquid_registers

def liquid_registers
  @liquid_registers ||= {
    site_id: Current.site&.id&.to_s&.freeze,
    resources: Liquid::ResourceRegistry.new(site: Current.site)
  }.freeze
end
```

The handler duplicates this hash on every nested render while intentionally sharing the registry object for that render/request.

- [ ] **Step 5: Route every repeated lookup through the registry**

In `AssetUrl`, fetch once with `@context.registers.fetch(:resources).asset(name)`, then use the returned record's blob. Keep the theme/static fallback when no uploaded asset exists.

In `RenderAction` and `RenderCampaign`, replace model class lookup with `context.registers.fetch(:resources).action(slug)` or `.campaign(slug)`. Preserve the current missing-action text and missing-campaign exception behavior.

In `ActionsDrop#[]` and `CampaignsDrop#[]`, use `@context.registers.fetch(:resources)` with `scope: object` when context exists. Keep a tenant-scoped registry fallback for direct Ruby use outside Liquid rendering.

- [ ] **Step 6: Enforce repeated-reference query ceilings**

Add render-level tests containing the same asset filter twice, the same `render_action` tag twice, and two lookups of the same action/campaign Drop key. Wrap each render with `assert_queries(1)` for the relevant fallback lookup. Add preloaded registry variants using `assert_no_queries` around resource retrieval.

Run: `docker compose run --rm -v /Users/sean/code/countable/liquid-rails:/gems/liquid-rails site bin/rails test test/services/liquid/resource_registry_test.rb test/lib/liquid/filters/asset_url_test.rb test/drops/action_drop_test.rb test/drops/schema_drop_test.rb`

Expected: PASS at the one-fallback-query ceiling.

- [ ] **Step 7: Commit tenant resource isolation**

```bash
git add site/app/controllers/application_controller.rb site/app/services/liquid site/app/drops site/lib/liquid site/test/services site/test/lib/liquid site/test/drops
git commit -m "perf: scope Liquid render resources by site"
```

### Task 8: Prove database-template and cache isolation in the site

**Repository:** `/Users/sean/code/csg/v2`

**Files:**
- Create: `site/test/integration/liquid_rendering_test.rb`
- Modify: `site/test/lib/themes/resolver_test.rb`
- Modify: `site/test/system/pages/templates/advocacy_test.rb`

**Interfaces:**
- Consumes: tenant cache namespace, source digest, environment generation, ResourceRegistry, and Themes::Resolver template identity.
- Produces: consumer-level proof that equal logical paths cannot couple tenant source, parsed state, or application records.

- [ ] **Step 1: Add a failing cross-tenant render integration test**

```ruby
class LiquidRenderingTest < ActiveSupport::TestCase
  test "same template identity stays isolated by site and source" do
    first_site = sites(:site)
    second_site = sites(:basic)
    metadata = {identifier: "Template - shared", virtual_path: "pages/shared", format: :html, locale: :en}

    first_output = render_for(first_site, "{{ site.name }} / {{ 'logo.png' | asset_url }}", metadata)
    second_output = render_for(second_site, "SECOND {{ site.name }} / {{ 'logo.png' | asset_url }}", metadata)
    changed_output = render_for(first_site, "CHANGED {{ site.name }}", metadata)

    assert_includes first_output, first_site.name
    refute_includes first_output, second_site.name
    assert_includes second_output, "SECOND #{second_site.name}"
    assert_equal "CHANGED #{first_site.name}", changed_output
  end

  private

  def render_for(site, source, metadata)
    Current.site = site
    controller = ApplicationController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new
    controller.setup_liquid_defaults
    Liquid::Rails::TemplateHandler.new(controller.view_context).render(source, {}, metadata)
  ensure
    Current.reset
  end
end
```

- [ ] **Step 2: Add resolver identity and source-change coverage**

Extend `ResolverTest` to create the same `path`, `format`, and `locale` for two different sites, assert each `ActionView::Template#identifier` contains its own record id, render both, update one body, and assert the updated source renders without affecting the other site.

- [ ] **Step 3: Run integration tests**

Run: `docker compose run --rm -v /Users/sean/code/countable/liquid-rails:/gems/liquid-rails site bin/rails test test/integration/liquid_rendering_test.rb test/lib/themes/resolver_test.rb`

Expected: PASS after the earlier cache and registry work. A failure in `Themes::Resolver` is reported separately because changing the application resolver is outside this migration's demonstrated requirements.

- [ ] **Step 4: Run a focused real page system path**

Add assertions to `site/test/system/pages/templates/advocacy_test.rb` that render the page twice under its fixture site and confirm the expected action title and CTA remain correct after cached parsing.

Run: `docker compose run --rm -v /Users/sean/code/countable/liquid-rails:/gems/liquid-rails site bin/rails test:system test/system/pages/templates/advocacy_test.rb`

Expected: PASS with the correct tenant's content on both renders.

- [ ] **Step 5: Commit consumer isolation coverage**

```bash
git add site/test/integration/liquid_rendering_test.rb site/test/lib/themes/resolver_test.rb site/test/system/pages/templates/advocacy_test.rb
git commit -m "test: prove tenant-safe Liquid rendering"
```

### Task 9: Publish migration documentation and run final verification

**Repositories:** `/Users/sean/code/countable/liquid-rails` and `/Users/sean/code/csg/v2`

**Files:**
- Modify: `/Users/sean/code/countable/liquid-rails/README.md`
- Modify: `/Users/sean/code/countable/liquid-rails/CHANGELOG.md`
- Modify: `/Users/sean/code/csg/v2/site/Gemfile.lock`
- Create: `/Users/sean/code/csg/v2/site/docs/liquid-rendering.md`
- Modify: `/Users/sean/code/csg/v2/site/docs/README.md`

**Interfaces:**
- Consumes: all completed public APIs and removed constants from Tasks 1–8.
- Produces: 1.0 usage/migration guide, clean lock state, complete verification evidence, and two independently reviewable repository histories.

- [ ] **Step 1: Document the final public configuration**

README examples must show:

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

Document `liquid_registers`, explicit `Droppable` inclusion, the collection allowlist, cache isolation rules, and both error policies.

- [ ] **Step 2: Write the 1.0 breaking-change ledger**

The changelog must explicitly list removal of Kaminari pagination, `active_link_to`, Google integrations, Webpacker tags, miscellaneous filters, non-Rails text utilities, global registration, and ORM injection. For each site-relevant removal, name the replacement `Liquid::Filters::Navigation` or `Liquid::Tags::Paginate`.

Create `site/docs/liquid-rendering.md` with the ownership boundary, the initializer registration list, the `liquid_registers` keys (`site_id` and `resources`), the full tenant cache-key inputs, the one-fallback-query ceiling, and the rule that parsed tags keep render state in locals/registers. Link it from `site/docs/README.md`.

- [ ] **Step 3: Run gem verification from a clean process**

Run in `/Users/sean/code/countable/liquid-rails`:

```bash
bundle exec rspec
bundle exec standardrb
gem build liquid-rails.gemspec
BUNDLE_GEMFILE=gemfiles/rails_80.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_80.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails_81.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_81.gemfile bundle exec rspec
```

Expected: every command exits 0; the gem builds as `liquid-rails-1.0.0.gem`; no Liquid Rails deprecation warnings appear.

- [ ] **Step 4: Run focused site verification with the local gem override**

Run in `/Users/sean/code/csg/v2`:

```bash
docker compose run --rm -v /Users/sean/code/countable/liquid-rails:/gems/liquid-rails site bin/rails test test/integration/liquid_environment_test.rb test/integration/liquid_rendering_test.rb test/lib/liquid test/lib/themes/resolver_test.rb test/services/liquid/resource_registry_test.rb test/drops/action_drop_test.rb test/drops/schema_drop_test.rb test/drops/form_field_drop_test.rb test/models/concerns/liquid_renderable_test.rb
docker compose run --rm -v /Users/sean/code/countable/liquid-rails:/gems/liquid-rails site bin/rails test:system test/system/pages/templates/advocacy_test.rb
docker compose run --rm -v /Users/sean/code/countable/liquid-rails:/gems/liquid-rails site bin/bundle exec rubocop
```

Expected: every command exits 0 with deterministic encryption configuration and no deprecated Liquid global registration.

- [ ] **Step 5: Run the complete site test suite**

Run: `docker compose run --rm -v /Users/sean/code/countable/liquid-rails:/gems/liquid-rails site bin/rails test:all`

Expected: exit 0. Classify any failure against the pre-change baseline; fix regressions caused by this migration and report unrelated pre-existing failures with their exact tests and output.

- [ ] **Step 6: Commit documentation and final lock state separately**

In the gem repository:

```bash
git add README.md CHANGELOG.md
git commit -m "docs: publish Liquid Rails 1.0 migration guide"
```

Refresh the platform lockfile against the completed local gem commit:

```bash
docker compose run --rm -v /Users/sean/code/countable/liquid-rails:/gems/liquid-rails site bundle update liquid-rails
```

Then commit in the platform repository:

```bash
git add site/Gemfile.lock site/docs/README.md site/docs/liquid-rendering.md
git commit -m "docs: record Liquid Rails 1.0 integration"
```

- [ ] **Step 7: Review final repository state**

Run:

```bash
git -C /Users/sean/code/countable/liquid-rails status --short --branch
git -C /Users/sean/code/countable/liquid-rails log --oneline --decorate -10
git -C /Users/sean/code/csg/v2 status --short --branch
git -C /Users/sean/code/csg/v2 log --oneline --decorate -10
```

Expected: both worktrees are clean; gem commits follow the design commit; platform commits follow and preserve the user's two pre-existing local commits.
