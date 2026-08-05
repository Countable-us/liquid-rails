# Liquid Rails 1.0 Modernization Design

**Status:** Design approved; written specification pending review

**Repositories:**

- Liquid Rails gem: `/Users/sean/code/countable/liquid-rails`
- Platform consumer: `/Users/sean/code/csg/v2/site`

## Purpose

Modernize Liquid Rails as a small, explicit Rails integration for Liquid 5 while preserving the platform application's behavior. The release establishes a clear ownership boundary: reusable Rails–Liquid behavior remains in the gem, application and vendor policy moves into `site/`, and unused legacy integrations are removed.

The application is multi-tenant. Each `site_id` can have its own Liquid source for the same logical template, so parsing, extension registration, render resources, and memoization must never leak state between sites.

## Supported Versions

Liquid Rails 1.0 supports:

- Ruby `>= 3.3`
- Rails `>= 8.0`, `< 8.2`
- Liquid `>= 5.13`, `< 6`

The gem CI matrix covers Ruby 3.3, 3.4, and 4.0 across representative Rails 8.0 and 8.1 combinations. Invalid combinations may be excluded explicitly when Rails or Ruby does not support them. The platform remains on its existing Ruby 3.4, Rails 8.1, and Liquid 5.13 line.

Kaminari is no longer a gem dependency. The 1.0 release notes identify removed integrations and the site migration required for `active_link_to` and pagination.

## Ownership Boundary

### Gem core

Liquid Rails owns the reusable integration surface:

- Action View template-handler registration
- Rails view lookup for Liquid includes
- a configurable, application-scoped `Liquid::Environment`
- render input construction and explicit render-error policy
- tenant-safe, bounded parsed-template caching
- `Drop`, `CollectionDrop`, and opt-in `Droppable`
- generic Action View filters for assets, URLs, translation, numbers, sanitization, dates, and text
- generic tags for `content_for`, `yield`, CSRF metadata, and `javascript_tag`
- optional RSpec helpers and matchers

The generic URL filter retains `link_to`, `link_to_unless_current`, `mail_to`, `current_page?`, and `url_for`. The generic text filter retains Rails helpers such as `highlight`, `excerpt`, `pluralize`, `word_wrap`, and `simple_format`.

### Site application

The platform owns behavior that depends on application models, tenant state, navigation policy, or a non-core vendor:

- `active_link_to`, exposed through a site-owned navigation filter
- Pagy pagination, exposed through a site-owned `paginate` tag
- tenant-backed asset lookup and render-scoped asset memoization
- site-aware date behavior such as `hours_ago`
- campaign, action, schema, layout, record, media, and string extensions
- resource registries that preload or memoize application records
- the explicit cache namespace that returns the current `site_id`

The `active_link_to` Ruby dependency remains in the site Gemfile because the admin ERB interface also uses it. Only its Liquid adapter moves out of the gem.

The site's CSRF and `yield` monkey patches are deleted after their generic nil-handling fixes are incorporated into the gem. The site's pagination monkey patch is replaced with a normal site tag class.

### Removed features

The gem removes unused, obsolete, or policy-heavy features:

- Kaminari and the Kaminari/Bootstrap pagination filter
- Google Static Maps filter
- Google Analytics tag
- Webpacker `javascript_pack_tag` and `stylesheet_pack_tag`
- the miscellaneous kitchen-sink filter
- non-Rails text utilities including `rjust`, `ljust`, `underscore`, `dasherize`, and custom concatenation

These removals are deliberate 1.0 breaking changes rather than compatibility shims.

## Environment and Extension Registration

Liquid Rails no longer registers extensions through `Liquid::Template` or mutates `Liquid::Environment.default`. It owns one environment reference for the Rails application and exposes these public operations:

- `Liquid::Rails.build_environment(error_mode: ...)` builds a fresh environment containing the gem's supported filters and tags and yields it for application registration.
- `Liquid::Rails.environment` returns the current environment.
- `Liquid::Rails.environment = environment` installs a completed environment and increments an internal environment generation used by the parse-cache key.
- `Liquid::Rails.configure` sets render and cache policy without registering global Liquid state.

The site initializer runs inside `Rails.application.config.to_prepare`. Each prepare pass builds a fresh environment, registers site filter and tag classes on that environment, and installs it atomically. This replaces globbed `require` calls and deprecated `Liquid::Template.register_filter` and `register_tag` calls. Rails autoloading loads site extension constants conventionally.

The template handler, include filesystem, and any nested rendering all parse through the installed environment. A render cannot parse with one environment and register extensions on another.

## Rendering Contract

The template handler treats controller assigns as immutable input. It creates a new assigns hash and a new registers hash for every render; it never adds reserved values to the caller's hash with `merge!`.

Configuration provides an explicit render-error policy:

- `:raise` uses Liquid's raising behavior and is the platform setting in every Rails environment.
- `:embed` returns Liquid's inline error output for applications that intentionally choose tolerant rendering.

Behavior never changes implicitly based on `Rails.env`.

The handler obtains application registers from a `liquid_registers` view hook when present and combines them with gem-owned `:view`, `:controller`, `:helpers`, and `:file_system` registers in a new hash. Reserved gem register names cannot be overridden by the hook. The site hook returns an immutable `site_id` and a per-render resource registry; the gem does not reference `Current` or any site model.

## Tenant-Safe Parsed-Template Cache

Parsed-template caching is disabled unless an application supplies a cache namespace callable. The platform callable returns the current immutable `site_id`; a missing site in a render that expects caching results in an uncached render, not a shared global cache entry.

The process-local cache is thread-safe and globally bounded. It defaults to 1,000 parsed-template entries across all tenants, and applications can configure a different positive global entry limit. It is not an unbounded map per tenant. Its key contains:

- the application-provided namespace (`site_id` in the platform)
- the installed environment generation
- template identifier or virtual path
- format and locale when available
- a digest of the complete Liquid source

The source digest makes edits produce a new entry without relying on model callbacks. Including `site_id` prevents equal paths or equal source from coupling tenant cache identity.

Only a parsed template prototype is cached. Each render duplicates the template wrapper so Liquid's error collection and `render!` state are render-local. Parsed nodes and site tag objects must not mutate per-render state; all render state belongs in Liquid context registers or local variables. No rendered output, assigns, Drops, records, controller, view, or register hash is cached.

Cache tests exercise two sites with the same path and different sources, source changes within one site, environment replacement, bounded eviction, and concurrent renders with distinct assigns and registers.

## Drops and Collections

`Liquid::Rails::Droppable` is no longer injected into all Active Record or Mongoid models. The site explicitly includes it in `Action`, `Page`, and `Reaction`, the models that intentionally use generated `*Drop` conversion. Existing explicit `to_liquid` methods remain explicit, and all other Drops continue to be constructed explicitly.

`Drop` initialization copies its options. It preserves `current_user` and other render options through association access, scope calls, indexing, pagination, and collection mapping without modifying class-level configuration or another Drop's state.

`CollectionDrop` exposes an explicit allowlist of Liquid operations. It does not delegate arbitrary Array methods, accept arbitrary `public_send` targets, or expose Ruby extension methods through Liquid. Query-backed operations remain lazy where Active Record supports them. Transformations wrap results with the same copied render options.

The site retains its application-specific `ApplicationDrop` hierarchy. Gem changes preserve the `object`, context, option propagation, and allowed association/scoping behavior required by those Drops.

## Site Resource and Query Behavior

The site implements a per-render resource registry supplied by `liquid_registers`. It captures `site_id` at construction and never resolves records outside that site. Campaign and action tags and Drops consult the registry before querying. Preloaded resources are used when available; fallback lookups are tenant-scoped and memoized for the duration of one render.

The site asset filter performs at most one tenant-scoped lookup for a given asset name during a render. Its memoization key includes `site_id` and asset name. Neither assets nor application records are stored in the parsed-template cache.

Focused integration tests enforce query ceilings for repeated asset, campaign, and action references. A repeated reference to the same asset name, campaign slug, or action slug performs at most one fallback lookup during one render; a preloaded reference performs none. Tests also prove that rendering the same source for two sites cannot reuse a record or URL from the other site.

## Loading and Rails Conventions

The gem replaces Ruby `autoload`, filesystem globs, and order-dependent side effects with explicit entry-point requires for gem code. Site extension files follow Zeitwerk naming and are loaded by Rails.

The Liquid include filesystem uses supported Action View lookup APIs and returns source with stable template identity. It does not call private six-argument resolver methods.

The Railtie only registers the template handler and generator preference. It does not modify ORM base classes or register global Liquid extensions.

## Test and Delivery Strategy

Implementation follows test-driven slices. Each behavioral change begins with a focused failing contract test, then the smallest implementation, then regression coverage.

Gem coverage includes:

- environment isolation and generation changes
- render input immutability and `:raise`/`:embed` policies
- Drop option isolation and propagation
- CollectionDrop allowlisting and laziness
- public Action View lookup behavior
- tenant-aware cache keys, eviction, invalidation, and concurrency
- generic filter and tag behavior retained in 1.0
- confirmation that removed constants and dependencies are absent

The gem pipeline runs the complete test suite, linting, and gem build across the supported dependency matrix. Deprecation warnings from Liquid Rails itself fail the relevant compatibility checks.

Site coverage includes:

- booting with the gem through its local path during coordinated development
- explicit environment and site extension registration
- the two existing Liquid `active_link_to` call sites
- Pagy pagination behavior
- nil-safe CSRF and `yield` behavior from the gem
- explicit model-to-Drop conversion
- tenant-separated parsing and resource lookup
- query ceilings for repeated application resources
- a focused end-to-end Liquid page render

Tests receive deterministic Active Record encryption keys through test-only configuration when credentials are unavailable locally. Production and other environments continue to require real credentials.

The gem and site changes are committed independently in their respective repositories. The site lockfile is updated to the completed gem revision or release source only after gem tests pass. Existing user commits in the platform repository remain untouched.

## Acceptance Criteria

The migration is complete when:

1. The gem declares and tests the approved Ruby, Rails, and Liquid ranges without Kaminari.
2. No gem code depends on `active_link_to`, Pagy, platform models, `Current`, or `site_id` semantics.
3. The site owns and registers `active_link_to`, Pagy, and every domain extension through its scoped environment.
4. The gem performs no deprecated global Liquid registration and no ORM-wide concern injection.
5. A render does not mutate caller assigns, share render registers, or leak Drop options.
6. Parsed-template cache identity includes `site_id`, environment generation, template identity, format/locale metadata, and source digest, and the cache enforces its configured global entry limit across tenants.
7. Cross-tenant and concurrent render tests demonstrate isolation.
8. A repeated campaign slug, action slug, or asset name performs no more than one fallback lookup per render and no lookup when preloaded.
9. The full gem suite, compatibility matrix, gem build, focused site integration suite, and selected site system path pass without Liquid Rails deprecation warnings.
10. Migration and release documentation identifies every removed API and its site-owned replacement.
