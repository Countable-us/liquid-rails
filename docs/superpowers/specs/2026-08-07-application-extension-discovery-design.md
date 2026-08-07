# Application Extension Discovery Design

## Scope

Liquid Rails will own the generic lifecycle and filename-based discovery used
to install application filters and tags into its isolated Liquid environment.
The application will continue to own the extension implementations and all
tenant-specific resource lookup behavior.

## Configuration

`Liquid::Rails::Configuration` will expose `filters_location` and
`tags_location`. Their defaults will be `lib/liquid/filters` and
`lib/liquid/tags`, resolved relative to `Rails.root`. Applications may provide
absolute paths, relative paths, or `nil`; `nil` disables discovery for that
extension type. A missing directory behaves like an empty directory.

Filter files will use the existing convention
`Liquid::Filters::<Filename.camelize>`. Tag files will use
`Liquid::Tags::<Filename.camelize>` and register under the underscored filename.
Only sorted, direct `.rb` children of the configured directory are discovered.

## Environment Lifecycle

The gem Railtie will rebuild and atomically install a fresh isolated Liquid
environment during every Rails prepare pass. Each environment contains the
gem's generic defaults plus the configured application extensions. Replacing
the environment advances the existing generation counter, so cached parsed
templates are reparsed against the current extension set.

The platform application will remove its local `LiquidEnvironmentInstaller`.
Its initializer will retain render-error and tenant-aware cache configuration;
it may set discovery locations only when overriding the conventional defaults.

## Tenant Boundary Documentation

The platform will document why `liquid_registers` is exposed as a controller
helper and why `ApplicationDrop#resource_registry` has an outside-render
fallback. The resource registry will continue to capture an immutable tenant
identifier for its lifetime and perform `unscoped` queries with an explicit
`site_id` predicate. This avoids coupling a memoized registry to the mutable,
thread-local `Current.site` default scope while preserving tenant isolation.

## Verification

Gem tests will prove default and custom discovery, missing and disabled
locations, deterministic registration, and prepare-cycle environment
replacement. Platform tests will prove its extensions remain registered and
that resource lookups remain bound to the registry's captured site even when
`Current.site` differs. Existing gem and platform test and style suites must
remain green.
