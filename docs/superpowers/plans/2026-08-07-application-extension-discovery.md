# Application Extension Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move conventional application filter and tag discovery into Liquid Rails while preserving the platform application's immutable per-render tenant boundary.

**Architecture:** Liquid Rails configuration names the filter and tag directories. A focused extension loader resolves those directories, loads sorted Ruby files, and registers filename-convention constants into a fresh isolated environment. The Railtie installs that environment on every Rails prepare pass; the platform retains only application policy, tenant cache configuration, and extension implementations.

**Tech Stack:** Ruby, Rails Railtie/reloader, Liquid 5/6, RSpec, Minitest, StandardRB, RuboCop

## Global Constraints

- Keep filter and tag implementations in the platform application.
- Default discovery locations are `lib/liquid/filters` and `lib/liquid/tags` relative to `Rails.root`.
- Absolute paths, relative paths, `Pathname` values, and `nil` are supported; `nil` disables that extension type.
- Missing directories are treated as empty.
- Only sorted direct `.rb` children are registered by filename convention.
- A registry's captured `site_id`, not mutable `Current.site`, remains the authority for every memoized resource lookup.
- No rendered output, records, Drops, controllers, views, or register hashes are cached.

---

### Task 1: Configuration API

**Files:**
- Create: `spec/lib/liquid-rails/configuration_spec.rb`
- Modify: `lib/liquid-rails/configuration.rb`
- Modify: `README.md`

**Interfaces:**
- Produces: `Liquid::Rails.configuration.filters_location` and `tags_location`, each accepting a path-like value or `nil`.

- [ ] **Step 1: Write failing configuration examples**

Add examples asserting new configurations default to the two conventional relative paths, accept strings and `Pathname` objects, and preserve `nil` as the discovery-disable value.

- [ ] **Step 2: Verify RED**

Run: `bundle exec rspec spec/lib/liquid-rails/configuration_spec.rb`

Expected: FAIL because both location readers and writers are absent.

- [ ] **Step 3: Implement the minimum configuration surface**

Add both readers, initialize the conventional defaults, and add writers that accept path-like values or `nil` without consulting `Rails.root`.

- [ ] **Step 4: Verify GREEN and document the API**

Run: `bundle exec rspec spec/lib/liquid-rails/configuration_spec.rb`

Document default, override, disable, and naming behavior in `README.md`.

- [ ] **Step 5: Commit**

```bash
git add lib/liquid-rails/configuration.rb spec/lib/liquid-rails/configuration_spec.rb README.md
git commit -m "feat: configure application extension locations"
```

### Task 2: Deterministic Extension Loader

**Files:**
- Create: `lib/liquid-rails/application_extensions.rb`
- Create: `spec/lib/liquid-rails/application_extensions_spec.rb`
- Modify: `lib/liquid-rails.rb`

**Interfaces:**
- Consumes: `filters_location`, `tags_location`, and a Rails application root.
- Produces: `Liquid::Rails::ApplicationExtensions.new(root:, configuration:).register(environment)` returning the supplied environment after registering discovered extensions.

- [ ] **Step 1: Write failing loader examples**

Use temporary directories and real test constants to prove that the loader:

- resolves a relative location against `root` and leaves an absolute location unchanged;
- registers `Liquid::Filters::ExampleFilter` from `example_filter.rb`;
- registers `Liquid::Tags::ExampleTag` as `example_tag`;
- ignores nested and non-Ruby files;
- processes files in sorted order;
- treats missing and `nil` locations as empty.

- [ ] **Step 2: Verify RED**

Run: `bundle exec rspec spec/lib/liquid-rails/application_extensions_spec.rb`

Expected: FAIL because `Liquid::Rails::ApplicationExtensions` is undefined.

- [ ] **Step 3: Implement the loader**

Resolve configured locations with `Pathname`, enumerate direct `.rb` children in lexical order, load each through Rails dependency loading, derive constants under `Liquid::Filters` or `Liquid::Tags`, and register them into the supplied isolated environment.

- [ ] **Step 4: Verify GREEN**

Run: `bundle exec rspec spec/lib/liquid-rails/application_extensions_spec.rb`

- [ ] **Step 5: Commit**

```bash
git add lib/liquid-rails.rb lib/liquid-rails/application_extensions.rb spec/lib/liquid-rails/application_extensions_spec.rb
git commit -m "feat: discover application liquid extensions"
```

### Task 3: Rails Prepare Lifecycle

**Files:**
- Modify: `lib/liquid-rails.rb`
- Modify: `lib/liquid-rails/railtie.rb`
- Modify: `spec/lib/liquid-rails/railtie_spec.rb`
- Modify: `spec/lib/liquid-rails/environment_spec.rb`

**Interfaces:**
- Produces: `Liquid::Rails.install_application_environment!(root:)`, which builds a strict isolated environment, applies configured extensions, atomically installs it, and advances the generation.
- Produces: a Railtie prepare callback that invokes that method with the application root after initialization and after code reloads.

- [ ] **Step 1: Write a failing environment-installation example**

Configure temporary filter and tag locations, invoke `install_application_environment!`, and assert the new environment contains the application extensions, is not `Liquid::Environment.default`, and advances `environment_generation`.

- [ ] **Step 2: Verify RED**

Run: `bundle exec rspec spec/lib/liquid-rails/environment_spec.rb`

Expected: FAIL because the installer method is absent.

- [ ] **Step 3: Implement the environment installer**

Build through `build_environment(error_mode: :strict)`, delegate extension registration to `ApplicationExtensions`, and assign through `environment=` so the existing mutex and generation semantics remain authoritative.

- [ ] **Step 4: Write and verify a failing Railtie prepare example**

Exercise `Rails.application.reloader.prepare!` and assert it calls the installer and advances the installed environment generation.

Run: `bundle exec rspec spec/lib/liquid-rails/railtie_spec.rb`

- [ ] **Step 5: Register the prepare callback and verify GREEN**

Add the callback through the application reloader in the Railtie, then run:

```bash
bundle exec rspec spec/lib/liquid-rails/environment_spec.rb spec/lib/liquid-rails/railtie_spec.rb
```

- [ ] **Step 6: Commit**

```bash
git add lib/liquid-rails.rb lib/liquid-rails/railtie.rb spec/lib/liquid-rails/environment_spec.rb spec/lib/liquid-rails/railtie_spec.rb
git commit -m "feat: reload liquid extensions on rails prepare"
```

- [ ] **Step 7: Push the gem branch for platform integration**

Push `codex/liquid-rails-1-0` so the platform's Git dependency can lock to
the implementation commit before its integration tests run.

### Task 4: Platform Integration and Review Explanations

**Files:**
- Modify: `site/config/initializers/liquid.rb`
- Modify: `site/Gemfile.lock`
- Modify: `site/app/controllers/application_controller.rb`
- Modify: `site/app/drops/application_drop.rb`
- Modify: `site/app/services/liquid/resource_registry.rb`
- Modify: `site/test/integration/liquid_environment_test.rb`
- Modify: `site/test/integration/liquid_environment_reload_test.rb`
- Modify: `site/test/services/liquid/resource_registry_test.rb`
- Modify: `site/docs/liquid-rendering.md`

**Interfaces:**
- Consumes: gem-managed conventional discovery and prepare lifecycle.
- Preserves: `liquid_registers => {site_id:, resources:}` and explicit `site_id` predicates in `Liquid::ResourceRegistry`.

- [ ] **Step 1: Write failing platform integration expectations**

Replace assertions against `LiquidEnvironmentInstaller` with assertions against the installed gem environment and make the development reload test invoke the Rails reloader without manually reinstalling Liquid. Strengthen the registry test so a registry created for one site still returns that site's records when `Current.site` is `nil` or points at another site.

- [ ] **Step 2: Verify RED against the current platform initializer**

Run from `site/`:

```bash
bin/rails test test/integration/liquid_environment_test.rb test/integration/liquid_environment_reload_test.rb test/services/liquid/resource_registry_test.rb
```

Expected: FAIL because the application still owns installation and the reload test still references `LiquidEnvironmentInstaller`.

- [ ] **Step 3: Remove the application installer and add detailed comments**

Update `Gemfile.lock` to the pushed gem implementation. Leave render policy,
cache size, and the `site_id` cache namespace in the initializer. Expand
comments to explain:

- why the controller exposes `liquid_registers` to the view context;
- why one registry is shared throughout a render;
- why Drops outside a Liquid context create a tenant-bound fallback registry;
- why registry queries use `unscoped` together with an explicit captured `site_id` instead of mutable `Current.site`.

Update the canonical Liquid rendering documentation so it describes the
gem-owned discovery and prepare lifecycle while retaining the application/gem
ownership boundary and tenant-resource rules.

- [ ] **Step 4: Verify GREEN**

Run the same targeted platform command and `bundle exec rake liquid:lint`.

- [ ] **Step 5: Commit the platform changes**

```bash
git add site/Gemfile.lock site/app/controllers/application_controller.rb site/app/drops/application_drop.rb site/app/services/liquid/resource_registry.rb site/config/initializers/liquid.rb site/docs/liquid-rendering.md site/test/integration/liquid_environment_test.rb site/test/integration/liquid_environment_reload_test.rb site/test/services/liquid/resource_registry_test.rb
git commit -m "refactor: use gem extension discovery"
```

### Task 5: Cross-Version Verification and PR Responses

**Files:**
- Modify if needed: files from Tasks 1-4 only.

**Interfaces:**
- Produces: verified gem and platform commits ready for both existing PRs.

- [ ] **Step 1: Run the complete gem matrix locally**

```bash
bundle exec rake
BUNDLE_GEMFILE=gemfiles/rails_80.gemfile bundle exec rake
BUNDLE_GEMFILE=gemfiles/rails_81.gemfile bundle exec rake
```

- [ ] **Step 2: Run platform verification**

From `site/`, run the full non-system Rails suite, RuboCop, and `liquid:lint` using the repository's container command when local dependencies are unavailable.

- [ ] **Step 3: Review diffs and repository state**

Run `git diff --check`, inspect the complete branch diff in both repositories, and verify only intentional files changed.

- [ ] **Step 4: Push both branches**

Push `codex/liquid-rails-1-0` and `codex/liquid-rails-1-0-site` after all verification succeeds.

- [ ] **Step 5: Reply inline to all five comments**

Explain the two documentation improvements, the explicit immutable tenant boundary and reason for `unscoped`, and the gem-owned discovery implementation with its configuration and reload behavior. Link each response to its corresponding commit where useful.
