# Changelog

## 1.0.0

### Breaking changes

- Ruby `>= 3.3`, Rails `>= 8.0, < 8.2`, and Liquid `>= 5.13, < 6` are now required.
- Kaminari and the Kaminari/Bootstrap pagination filter have been removed. Applications using the site integration should use the site-owned `Liquid::Tags::Paginate` tag, backed by Pagy, instead.
- The Liquid `active_link_to` integration has been removed from the gem. Applications using it should register the site-owned `Liquid::Filters::Navigation` filter instead.
- Google Static Maps and Google Analytics integrations have been removed.
- Webpacker `javascript_pack_tag` and `stylesheet_pack_tag` have been removed. Use the current application asset pipeline or application-owned extensions.
- The miscellaneous kitchen-sink filter has been removed.
- Non-Rails text utilities have been removed, including `rjust`, `ljust`, `underscore`, `dasherize`, and custom concatenation.
- Global Liquid registration has been removed. Configure extensions with `Liquid::Rails.build_environment` and install them through `Liquid::Rails.environment =`.
- ORM-wide `Droppable` injection has been removed. Include `Liquid::Rails::Droppable` explicitly in each model that exposes a generated Drop.

### New rendering model

- The gem owns an explicit, application-scoped `Liquid::Environment` and a configurable `:raise` or `:embed` render-error policy.
- Parsed-template caching is thread-safe, globally bounded (1,000 entries by default), and disabled without an application namespace. Tenant applications should namespace it with an immutable tenant key such as `site_id`.
- Each render receives fresh assigns and registers; cached parsed templates are duplicated before rendering. Custom tags must keep render state in locals or Liquid registers, never mutable tag instance variables.

## 0.2.3

### Breaking Changes

* Update `asset_url` to point to current site's assets

## 0.2.2

### New Features

* Add javascript_pack_tag and stylesheet_pack_tag

## 0.2.1

* Upgrade dependency versions.
* Resolve Rails deprecation notices
* Update translation filter for ActionView 6.x

## 0.2.0

### Resolved Issues

* Fix `Content-Type` issue
* Support from Liquid v4, Rails v5, and Kaminari v1 and up
* Use `ActionView::Resolver` as Liquid filesystem (lowang, streppa-ent)

## 0.1.4

### Resolved Issues

* Fix Filter overrides registered public methods as non public: h
* Support Liquid v3.0.6, Rails belows 5, and Kaminari below v1.0.0

## 0.1.2

### New Features

* Use google analytics universal (Chamnap Chhorn)

* Render liquid template as html_safe by default (Dan Kubb)

## 0.1.1

### New Features

* Add `bootstrap_pagination` filter. (Radin Reth)

* Allow `translate` filter with interpolation. (Tomasz Stachewicz, Chamnap Chhorn)

* Support `rails` 4.2 and `ruby` 2.2. (Chamnap Chhorn)

* Support `scope` on collection drop. (Radin Reth)

### Resolved Issues

* Add `rel="prev"` and `rel="next"` to `default_pagination` filter. (Radin Reth)

* Fix `content_for` and `yield` tag on `rails` 3.2. (Chamnap Chhorn)

* \#4 Makes partial template work in namespaced controller. (Tomasz Stachewicz)

* `truncate` filter now forwards to the standard filters. (Radin Reth)

## 0.1.0

* Initial Release
